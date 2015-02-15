require 'terminfo'
$LOAD_PATH.unshift File.dirname(__FILE__) + "/../../../yap-shell-line-parser/lib"
require 'yap/line/parser'
require 'yap/line/my_parser'

module Yap
  class Repl
    def initialize(world:)
      @world = world
    end

    require 'terminfo'
    include Term::ANSIColor
    def print_time(on:)
      # t.control "cud", 1
      time_str = Time.now.strftime("%H:%M:%S")
      h, w = t.screen_size
      t.control "sc"
      t.control "cub", w
      if on == :previous_row
        t.control "cuu", 1
      end
      t.control "cuf", w - time_str.length
      t.write bright_black(time_str)
      t.control "rc"
    end

    attr_reader :t
    def loop_on_input(&blk)
      @blk = blk
      @t = TermInfo.new("xterm-256color", STDOUT)
      @stdin = $stdin
      @stdout = $stdout
      @stderr = $stderr

      loop do
        # t.control "clear"
        # t.control "cwin", 0, 0, 100, 100

        heredoc = nil

        begin
          thr = Thread.new do
            loop do
              print_time on: :current_row
              sleep 1
            end
          end
          thr.abort_on_exception = true

          input = Readline.readline("#{@world.prompt}", true)
          Thread.kill(thr)

          print_time on: :previous_row
          next if input == ""

          input = process_heredoc(input)

          ast = Yap::Line::MyParser.new.parse(input)

          ast.accept self
        rescue ::Yap::CommandUnknownError => ex
          puts "  CommandError: #{ex.message}"
        rescue Interrupt
          puts "^C"
          next
        rescue SuspendSignalError
          # no-op since if we got here we're on the already at the top-level
          # repl and there's nothing to suspend but ourself and we're not
          # about to do that.
          puts "^Z"
          next
        end

      end
    end

    def visit_CommandNode(node)
      original_stdin = @stdin
      original_stdout = @stdout
      original_stderr = @stderr

      command = CommandFactory.build_command_for(node)

      node.redirects.each do |redirect|
        case redirect.kind
        when "<"
          @stdin = redirect.target
        when ">", "1>"
          @stdout = redirect.target
        when "1>&2"
          @stderr = :stdout
        when "2>"
          @stderr = redirect.target
        when "2>&1"
          @stdout = :stderr
        end
      end

      @last_result = @blk.call command, @stdin, @stdout, @stderr

      @stdin = original_stdin
      @stdout = original_stdout
      @stderr = original_stderr
    end

    def visit_StatementsNode(node)
      node.head.accept(self)
      node.tail.accept(self) if node.tail
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
      original_stdin = @stdin
      original_stdout = @stdout
      original_stderr = @stderr

      r,w = IO.pipe

      @stdout = w
      @stderr = w

      node.head.accept(self)

      @stdin = r
      @stdout = original_stdout
      @stderr = original_stderr

      node.tail.accept(self)

      @stdin = original_stdin
    end

    def visit_InternalEvalNode(node)
      command = CommandFactory.build_command_for(node)
      @last_result = @blk.call command, @stdin, @stdout, @stderr
    end

    private

    def convert_statements_to_command_chain(statements, heredoc:nil)
      commands = statements.map do |statement|
        command = CommandFactory.build_command_for(statement)
        command.args = statement.args if statement.respond_to?(:args)
        command
      end
      commands.last.heredoc = heredoc
      commands
    end

    def expand_statement(statement)
      return [statement] if statement.internally_evaluate?
      results = []
      aliases = Aliases.instance
      command = statement.command
      loop do
        if str=aliases.fetch_alias(command)
          statements = Yap::Line::Parser.parse("#{str} #{statement.args.join(' ')}")
          statements.map do |s|
            results.concat expand_statement(s)
          end
          return results
        else
          results << statement
          return results
        end
      end
    end

    def process_heredoc(_input)
      if _input =~ /<<-?([A-z0-9\-]+)\s*$/
        input = _input.dup
        marker = $1
        input << "\n"
      else
        return _input
      end

      puts "Beginning heredoc" if ENV["DEBUG"]
      loop do
        str = Readline.readline("> ", true)
        input << "#{str}\n"
        if str =~ /^#{Regexp.escape(marker)}$/
          puts "Ending heredoc" if ENV["DEBUG"]
          break
        end
      end
      input
    end

  end
end
