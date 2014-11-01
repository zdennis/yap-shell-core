module Lagniappe
  class Repl
    def initialize(world:)
      @world = world
    end

    def loop_on_input(&blk)
      loop do
        input = Readline.readline("#{@world.prompt}", true)
        input.strip!
        next if input == ""

        if input =~ /<<(-)?(\S+)/
          puts "Beginning heredoc" if ENV["DEBUG"]
          # heredoc
          input << "\n"
          allow_whitespace = !!$1
          end_marker = $2
          loop do
            print "> "
            str = gets
            input << str
            if str.to_s =~ /^#{Regexp.escape(end_marker)}/
              puts "BREAK" if ENV["DEBUG"]
              break
            end
          end
        else
          puts "No heredoc" if ENV["DEBUG"]
        end

        line = Line.new(input)
        yield line.commands if block_given?
      end
    end
  end
end
