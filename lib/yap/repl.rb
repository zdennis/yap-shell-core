require 'terminfo'
require 'yap/line/parser'

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
      @t = TermInfo.new("xterm-256color", STDOUT)

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

          statements = Yap::Line::Parser.parse(input)
          heredoc = process_heredoc marker:statements.last.heredoc_marker

          statements = statements.map do |statement|
            expand_statement(statement)
          end.flatten

          commands = convert_statements_to_command_chain(statements, heredoc:heredoc)
          yield commands if block_given?
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

    def process_heredoc(marker:)
      return nil if marker.nil?

      puts "Beginning heredoc" if ENV["DEBUG"]
      String.new.tap do |heredoc|
        heredoc << "<<#{marker}\n"
        loop do
          str = Readline.readline("> ", true)
          heredoc << "#{str}\n"
          if str =~ /^#{Regexp.escape(marker)}$/
            puts "Ending heredoc" if ENV["DEBUG"]
            break
          end
        end
      end
    end

  end
end
