require 'readline'

module Yap
  class Shell
    class Repl
      def initialize(world:nil)
        @world = world
      end

      def loop_on_input(&blk)
        @blk = blk

        loop do
          heredoc = nil
          prompt = ""

          begin
            prompt = @world ? @world.prompt : "> "
            input = Readline.readline("#{prompt}", true)

            next if input == ""

            input = process_heredoc(input)

            yield input
          rescue ::Yap::Shell::CommandUnknownError => ex
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
end
