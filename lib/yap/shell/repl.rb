require 'readline'

module Yap::Shell
  class Repl
    def initialize(world:nil)
      @world = world
    end

    def loop_on_input(&blk)
      @blk = blk

      loop do
        heredoc = nil

        begin
          input = Readline.readline("#{@world.prompt.update.text}", true)

          next if input == ""

          input = process_heredoc(input)

          yield input
        rescue ::Yap::Shell::CommandUnknownError => ex
          puts "  CommandError: #{ex.message}"
        rescue Interrupt
          puts "^C"
          next
        # rescue Exception => ex
        #   require 'pry'
        #   binding.pry
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
