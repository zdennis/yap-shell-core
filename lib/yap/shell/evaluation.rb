require 'yap/shell/parser'
require 'yap/shell/commands'
require 'yap/shell/aliases'

module Yap::Shell
  class Evaluation
    def initialize(stdin:, stdout:, stderr:, world:, last_result:nil)
      @stdin, @stdout, @stderr = stdin, stdout, stderr
      @world = world
      @last_result = last_result
    end

    def evaluate(input, &blk)
      @blk = blk
      input = recursively_find_and_replace_command_substitutions(input)
      ast = Parser.parse(input)
      ast.accept(self)
    end

    def status_code
      @last_result.status_code
    end

    private

    # +recursively_find_and_replace_command_substitutions+ is responsible for recursively
    # finding and expanding command substitutions, in a depth first manner.
    def recursively_find_and_replace_command_substitutions(input)
      input = input.dup
      Parser.each_command_substitution_for(input) do |substitution_result, start_position, end_position|
        result = recursively_find_and_replace_command_substitutions(parser, substitution_result.str)
        position = substitution_result.position
        ast = Parser.parse(result)
        with_standard_streams do |stdin, stdout, stderr|
          r,w = IO.pipe
          @stdout = w
          ast.accept(self)
          input[position.min...position.max] = r.read.chomp
        end
      end
      input
    end


    ######################################################################
    #                                                                    #
    #               VISITOR METHODS FOR AST TREE WALKING                 #
    #                                                                    #
    ######################################################################

    def visit_CommandNode(node)
      @aliases_expanded ||= []
      with_standard_streams do |stdin, stdout, stderr|
        args = node.args.map(&:lvalue).map{ |arg| env_expand(arg) }
        if !node.literal? && !@aliases_expanded.include?(node.command) && _alias=Aliases.instance.fetch_alias(node.command)
          @suppress_events = true
          ast = Parser.parse([_alias].concat(args).join(" "))
          @aliases_expanded.push(node.command)
          ast.accept(self)
          @aliases_expanded.pop
          @suppress_events = false
        else
          cmd2execute = env_expand(node.command)
          command = CommandFactory.build_command_for(
            command: cmd2execute,
            args:    shell_expand(args),
            heredoc: node.heredoc,
            internally_evaluate: node.internally_evaluate?)
          @stdin, @stdout, @stderr = stream_redirections_for(node)
          @last_result = @blk.call command, @stdin, @stdout, @stderr, pipeline_stack.empty?
        end
      end
    end

    def visit_StatementsNode(node)
      Yap::Shell::Execution::Context.fire :before_statements_execute, @world unless @suppress_events
      node.head.accept(self)
      if node.tail
        node.tail.accept(self)
      end
      Yap::Shell::Execution::Context.fire :after_statements_execute, @world unless @suppress_events
    end

    # Represents a statement that has scoped environment variables being set,
    # e.g.:
    #
    #    yap> A=5 ls
    #    yap> A=5 B=6 echo
    #
    # These environment variables are reset after the their statement, e.g.:
    #
    #    yap> A=5
    #    yap> echo $A
    #    5
    #    yap> A=b echo $A
    #    b
    #    yap> echo $
    #    5
    #
    def visit_EnvWrapperNode(node)
      with_env do
        node.env.each_pair { |env_var_name,value| ENV[env_var_name] = value }
        node.node.accept(self)
      end
    end

    # Represents a statement that contains nothing but environment
    # variables being set, e.g.:
    #
    #    yap> A=5
    #    yap> A=5 B=6
    #    yap> A=3 && B=6
    #
    # The environment variables persist from statement to statement until
    # they cleared or overridden.
    #
    def visit_EnvNode(node)
      node.env.each_pair do |key,val|
        ENV[key] = val
      end
      Yap::Shell::Execution::Result.new(status_code:0, directory:Dir.pwd, n:1, of:1)
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
        pipeline_stack.push true
        # Don't modify @stdin for the first command in the pipeline.
        node.head.accept(self)

        # Modify @stdin starting with the second command to read from the
        # read portion of our above stdout.
        @stdin = stdin

        # Modify @stdout,@stderr to go back to the original
        @stdout, @stderr = stdout, stderr

        pipeline_stack.pop
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
      @last_result = @blk.call command, @stdin, @stdout, @stderr, pipeline_stack.empty?
    end

    ######################################################################
    #                                                                    #
    #               HELPER / UTILITY METHODS                             #
    #                                                                    #
    ######################################################################


    # +pipeline_stack+ is used to determine if we are about go inside of a
    # pipeline. It will be empty when we are coming out of a pipeline node.
    def pipeline_stack
      @pipeline_stack ||= []
    end

    def alias_expand(input, aliases:Aliases.instance)
      head, *tail = input.split(/\s/, 2).first
      if new_head=aliases.fetch_alias(head)
        [new_head].concat(tail).join(" ")
      else
        input
      end
    end

    def env_expand(input)
      input.gsub(/\$(\S+)/) do |match,*args|
        var_name = match[1..-1]
        case var_name
        when "?"
          @last_result ? @last_result.status_code.to_s : '0'
        else
          ENV.fetch(var_name){ match }
        end
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

    def with_env(&blk)
      env = ENV.to_h
      begin
        yield if block_given?
      ensure
        ENV.clear
        ENV.replace(env)
      end
    end
  end
end
