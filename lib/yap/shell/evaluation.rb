$LOAD_PATH.unshift File.dirname(__FILE__) + "/../../../../yap-shell-line-parser/lib"
require 'yap/line/my_parser'

require 'yap/shell/commands'

module Yap
  class Shell
    class Evaluation
      def initialize(stdin:, stdout:, stderr:)
        @stdin, @stdout, @stderr = stdin, stdout, stderr
      end

      def evaluate(input, &blk)
        @blk = blk
        ast = Yap::Line::MyParser.new.parse(input)
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
          if !@aliases_expanded.include?(node.command) && _alias=Aliases.instance.fetch_alias(node.command)
            @suppress_events = true
            ast = Yap::Line::MyParser.new.parse([_alias].concat(node.args).join(" "))
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
        Yap::ExecutionContext.fire :before_statements_execute, self unless @suppress_events
        node.head.accept(self)
        if node.tail
          node.tail.accept(self)
          ENV.clear
          ENV.replace(env)
        end
        Yap::ExecutionContext.fire :after_statements_execute, self unless @suppress_events
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
          @stderr = @stdout

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
        [input].flatten.map do |str|
          str.gsub!(/\A~(.*)/, ENV["HOME"] + '\1')
          if str =~ /^\$(.*)/
            str = ENV.fetch($1, "")
          end
          expanded = Dir[str]
          expanded.any? ? expanded : str
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
end
