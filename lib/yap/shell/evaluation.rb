require 'yap/shell/parser'
require 'yap/shell/commands'
require 'yap/shell/aliases'

module Yap::Shell
  class Evaluation
    def initialize(stdin:, stdout:, stderr:)
      @stdin, @stdout, @stderr = stdin, stdout, stderr
      @last_result = nil
    end

    def evaluate(input, &blk)
      @blk = blk
      ast = Yap::Shell::Parser.new.parse(input)
      ast.accept(self)
    end

    private

    ######################################################################
    #                                                                    #
    #               VISITOR METHODS FOR AST TREE WALKING                 #
    #                                                                    #
    ######################################################################

    def visit_CommandNode(node)
      @aliases_expanded ||= []
      with_standard_streams do |stdin, stdout, stderr|
        if !node.literal? && !@aliases_expanded.include?(node.command) && _alias=Aliases.instance.fetch_alias(node.command)
          @suppress_events = true
          ast = Yap::Shell::Parser.new.parse([_alias].concat(node.args).join(" "))
          @aliases_expanded.push(node.command)
          ast.accept(self)
          @aliases_expanded.pop
          @suppress_events = false
        else
          command = CommandFactory.build_command_for(
            command: node.command,
            args:    shell_expand(node.args),
            heredoc: node.heredoc,
            internally_evaluate: node.internally_evaluate?)
          @stdin, @stdout, @stderr = stream_redirections_for(node)
          @last_result = @blk.call command, @stdin, @stdout, @stderr
        end
      end
    end

    def visit_StatementsNode(node)
      env = ENV.to_h
      Yap::Shell::Execution::Context.fire :before_statements_execute, self unless @suppress_events
      node.head.accept(self)
      if node.tail
        node.tail.accept(self)
        ENV.clear
        ENV.replace(env)
      end
      Yap::Shell::Execution::Context.fire :after_statements_execute, self unless @suppress_events
    end

    def visit_EnvWrapperNode(node)
      env = ENV.to_h
      node.env.each_pair do |k,v|
        ENV[k] = v
      end
      node.node.accept(self)
      ENV.clear
      ENV.replace(env)
    end

    def visit_EnvNode(node)
      node.env.each_pair do |key,val|
        ENV[key] = val
      end
    end

    def visit_ConditionalNode(node)
      case node.operator
      when '&&'
        node.expr1.accept self
        if @last_result.status_code == 0
          node.expr2.accept self
        end
      when '||'
        node.expr1.accept self
        if @last_result.status_code != 0
          node.expr2.accept self
        end
      else
        raise "Don't know how to visit conditional node: #{node.inspect}"
      end
    end

    def visit_PipelineNode(node, options={})
      with_standard_streams do |stdin, stdout, stderr|
        # Modify @stdout and @stderr for the first command
        stdin, @stdout = IO.pipe

        # Don't modify @stdin for the first command in the pipeline.
        node.head.accept(self)

        # Modify @stdin starting with the second command to read from the
        # read portion of our above stdout.
        @stdin = stdin

        # Modify @stdout,@stderr to go back to the original
        @stdout, @stderr = stdout, stderr

        node.tail.accept(self)

        # Set our @stdin back to the original
        @stdin = stdin
      end
    end

    def visit_InternalEvalNode(node)
      command = CommandFactory.build_command_for(
        command: node.command,
        args:    node.args,
        heredoc: node.heredoc,
        internally_evaluate: node.internally_evaluate?)
      @last_result = @blk.call command, @stdin, @stdout, @stderr
    end

    ######################################################################
    #                                                                    #
    #               HELPER / UTILITY METHODS                             #
    #                                                                    #
    ######################################################################

    def alias_expand(input, aliases:Aliases.instance)
      head, *tail = input.split(/\s/, 2).first
      if new_head=aliases.fetch_alias(head)
        [new_head].concat(tail).join(" ")
      else
        input
      end
    end

    def shell_expand(input)
      [input].flatten.inject([]) do |results,str|
        # Basic bash-style brace expansion
        expansions = str.scan(/\{([^\}]+)\}/).flatten.first
        if expansions
          expansions.split(",").each do |expansion|
            results << str.sub(/\{([^\}]+)\}/, expansion)
          end
        else
          results << str
        end

        results = results.map! do |s|
          # Basic bash-style tilde expansion
          s.gsub!(/\A~(.*)/, ENV["HOME"] + '\1')

          # Basic bash-style variable expansion
          if s =~ /^\$(.*)/
            s = ENV.fetch($1, "")
          end

          # Basic bash-style path-name expansion
          expansions = Dir[s]
          if expansions.any?
            expansions
          else
            s
          end
        end.flatten
      end.flatten
    end

    def with_standard_streams(&blk)
      stdin, stdout, stderr = @stdin, @stdout, @stderr
      yield stdin, stdout, stderr
      @stdin, @stdout, @stderr = stdin, stdout, stderr
    end

    def stream_redirections_for(node)
      stdin, stdout, stderr = @stdin, @stdout, @stderr
      node.redirects.each do |redirect|
        case redirect.kind
        when "<"
          stdin = redirect.target
        when ">", "1>"
          stdout = redirect.target
        when "1>&2"
          stderr = :stdout
        when "2>"
          stderr = redirect.target
        when "2>&1"
          stdout = :stderr
        end
      end
      [stdin, stdout, stderr]
    end

  end
end
