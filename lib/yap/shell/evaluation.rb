require 'yap/shell/parser'
require 'yap/shell/commands'
require 'yap/shell/aliases'
require 'yap/shell/evaluation/shell_expansions'

module Yap::Shell
  class Evaluation
    attr_reader :world

    def initialize(stdin:, stdout:, stderr:, world:)
      @stdin, @stdout, @stderr = stdin, stdout, stderr
      @world = world
    end

    def evaluate(input, &blk)
      @blk = blk
      @input = recursively_find_and_replace_command_substitutions(input)
      ast = Parser.parse(@input)
      ast.accept(self)
    end

    def set_last_result(result)
      @world.last_result = result
    end

    private

    # +recursively_find_and_replace_command_substitutions+ is responsible for recursively
    # finding and expanding command substitutions, in a depth first manner.
    def recursively_find_and_replace_command_substitutions(input)
      input = input.dup
      Parser.each_command_substitution_for(input) do |substitution_result, start_position, end_position|
        result = recursively_find_and_replace_command_substitutions(substitution_result.str)
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
      @command_node_args_stack ||= []
      with_standard_streams do |stdin, stdout, stderr|
        args = process_ArgumentNodes(node.args)
        if !node.literal? && !@aliases_expanded.include?(node.command) && _alias=Aliases.instance.fetch_alias(node.command)
          @suppress_events = true
          @command_node_args_stack << args
          ast = Parser.parse(_alias)
          ast.redirects = node.redirects
          @aliases_expanded.push(node.command)
          ast.accept(self)
          @aliases_expanded.pop
          @suppress_events = false
        else
          cmd2execute = variable_expand(node.command)
          final_args = (args + @command_node_args_stack).flatten.map(&:shellescape)
          expanded_args = shell_expand(final_args)
          command = CommandFactory.build_command_for(
            world: world,
            command: cmd2execute,
            args:    expanded_args,
            heredoc: (node.heredoc && node.heredoc.value),
            internally_evaluate: node.internally_evaluate?,
            line: @input)
          @stdin, @stdout, @stderr = stream_redirections_for(node)
          set_last_result @blk.call command, @stdin, @stdout, @stderr, pipeline_stack.empty?
          @command_node_args_stack.clear
        end
      end
    end

    def visit_CommentNode(node)
      # no-op, do nothing
    end

    def visit_RangeNode(node)
      range = node.head.value
      if node.tail
        @current_range_values = range.to_a
        node.tail.accept(self)
        @current_range_values = nil
      else
        @stdout.puts range.to_a.join(' ')
      end
    end

    def visit_RedirectionNode(node)
      filename = node.target

      if File.directory?(filename)
        puts <<-ERROR.gsub(/^\s*/m, '').lines.join(' ')
          Whoops, #{filename.inspect} is a directory! Those can't be redirected to.
        ERROR
        set_last_result Yap::Shell::Execution::Result.new(status_code:1, directory:Dir.pwd, n:1, of:1)
      elsif node.kind == ">"
        File.write(filename, "")
        set_last_result Yap::Shell::Execution::Result.new(status_code:0, directory:Dir.pwd, n:1, of:1)
      else
        puts "Sorry, #{node.kind} redirection isn't a thing, but >#{filename} is!"
        set_last_result Yap::Shell::Execution::Result.new(status_code:2, directory:Dir.pwd, n:1, of:1)
      end
    end

    def visit_BlockNode(node)
      with_standard_streams do |stdin, stdout, stderr|
        # Modify @stdout and @stderr for the first command
        stdin, @stdout = IO.pipe

        # Don't modify @stdin for the first command in the pipeline.
        values = []
        if node.head
          node.head.accept(self)
          values = stdin.read.split(/\s+/)
        else
          # assume range for now
          values = @current_range_values
        end

        evaluate_block = lambda {
          with_standard_streams do |stdin2, stdout2, stderr2|
            @stdout = stdout
            node.tail.accept(self)
          end
        }

        if node.params.any?
          values.each_slice(node.params.length).each do |_slice|
            with_env do
              Hash[ node.params.zip(_slice) ].each_pair do |k,v|
                world.env[k] = v.to_s
              end
              evaluate_block.call
            end
          end
        else
          values.each do
            evaluate_block.call
          end
        end
      end

    end

    def visit_NumericalRangeNode(node)
      node.range.each do |n|
        if node.tail
          if node.reference
            with_env do
              world.env[node.reference.value] = n.to_s
              node.tail.accept(self)
            end
          else
            node.tail.accept(self)
          end
        end
      end
    end

    def visit_StatementsNode(node)
      Yap::Shell::Execution::Context.fire :before_statements_execute, @world unless @suppress_events

      c = rand(100)
      $z.puts "visit_StatementsNode #{c}:0 @stdout=#{@stdout}  $stdout=#{$stdout} STDOUT=#{STDOUT}"
      $z.puts "#{node.inspect}"

      with_standard_streams do |stdin, stdout, stderr|
        @stdin, @stdout, @stderr = stream_redirections_for(node)
        $stdin, $stdout, $stderr = @stdin, @stdout, @stderr
        node.head.accept(self)
        if node.tail
          node.tail.accept(self)
        end
      end
      $z.puts "visit_StatementsNode #{c} done"

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
        node.env.each_pair do |env_var_name, arg_node|
          world.env[env_var_name] = process_ArgumentNode(arg_node)
        end
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
      node.env.each_pair do |key, arg_node|
        world.env[key] = process_ArgumentNode(arg_node)
      end
      Yap::Shell::Execution::Result.new(status_code:0, directory:Dir.pwd, n:1, of:1)
    end

    def visit_ConditionalNode(node)
      case node.operator
      when '&&'
        node.expr1.accept self
        if @world.last_result.status_code == 0
          node.expr2.accept self
        end
      when '||'
        node.expr1.accept self
        if @world.last_result.status_code != 0
          node.expr2.accept self
        end
      else
        raise "Don't know how to visit conditional node: #{node.inspect}"
      end
    end

    def visit_PipelineNode(node, options={})
      c = rand(100)
      $z.puts "visit_PipelineNode #{c}:0 @stdout=#{@stdout}  $stdout=#{$stdout} STDOUT=#{STDOUT}"
      $z.puts "#{node.inspect}"

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
        node.tail.accept(self) if node.tail

        # Set our @stdin back to the original
        @stdin = stdin
      end

      $z.puts "visit_PipelineNode #{c} done"
    end

    def visit_InternalEvalNode(node)
      command = CommandFactory.build_command_for(
        world: world,
        command: node.command,
        args:    node.args,
        heredoc: node.heredoc,
        internally_evaluate: node.internally_evaluate?,
        line: @input)
      set_last_result @blk.call command, @stdin, @stdout, @stderr, pipeline_stack.empty?
    end

    ######################################################################
    #                                                                    #
    #               HELPER / UTILITY METHODS                             #
    #                                                                    #
    ######################################################################

    def process_ArgumentNodes(nodes)
      nodes.map { |arg_node| process_ArgumentNode(arg_node) }
    end

    def process_ArgumentNode(node)
      if node.quoted?
        variable_expand(node.lvalue)
      else
        shell_expand(node.lvalue, escape_directory_expansions: false).first
      end
    end

    # +pipeline_stack+ is used to determine if we are about go inside of a
    # pipeline. It will be empty when we are coming out of a pipeline node.
    def pipeline_stack
      @pipeline_stack ||= []
    end

    def alias_expand(input)
      ShellExpansions.new(world: world).expand_aliases_in(input)
    end

    def variable_expand(input)
      ShellExpansions.new(world: world).expand_variables_in(input)
    end

    def shell_expand(input, escape_directory_expansions: true)
      ShellExpansions.new(world: world).expand_words_in(
        input,
        escape_directory_expansions: escape_directory_expansions
      )
    end

    def with_standard_streams(&blk)
      global_stdin, global_stdout, global_stderr = $stdin, $stdout, $stderr
      stdin, stdout, stderr = @stdin, @stdout, @stderr
      yield stdin, stdout, stderr
      @stdin, @stdout, @stderr = stdin, stdout, stderr
      $stdin, $stdout, $stderr = global_stdin, global_stdout, global_stderr
    end

    def stream_redirections_for(node)
      stdin, stdout, stderr = @stdin, @stdout, @stderr
      node.redirects.each do |redirect|
        case redirect.kind
        when "<"
          stdin = redirect.target
          stdin  = File.open(stdin, "rb") if stdin.is_a?(String)
        when ">", "1>"
          stdout = redirect.target
          stdout = File.open(stdout, "wb") if stdout.is_a?(String)
        when "1>&2"
          stderr = :stdout
        when "2>"
          stderr = redirect.target
          stderr = File.open(stderr, "wb") if stderr.is_a?(String)
        when "2>&1"
          stdout = :stderr
        end

        stdout = stderr if stdout == :stderr
        stderr = stdout if stderr == :stdout
      end
      [stdin, stdout, stderr]
    end

    def with_env(&blk)
      env = world.env.dup
      begin
        yield if block_given?
      ensure
        world.env.clear
        world.env.replace(env)
      end
    end
  end
end
