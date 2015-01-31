module Lagniappe
  class Repl
    def initialize(world:)
      @world = world
    end

    def loop_on_input(&blk)
      loop do
        heredoc = nil

        begin
          input = Readline.readline("#{@world.prompt}", true)
          next if input == ""

          arr = input.scan(/^(.*?)(<<(-)?(\S+)\s*)?$/).flatten
          statements, heredoc_start, heredoc_allow_whitespace, heredoc_end_marker = arr

          if heredoc_start
            heredoc = process_heredoc start:heredoc_start, marker: heredoc_end_marker
          else
            # arr = input.scan().flatten
          end

          line = Line.new(statements, heredoc:heredoc)
          yield line.commands if block_given?
        rescue Interrupt
          puts "^C"
          next
        end

      end
    end

    private

    def process_heredoc(start:, marker:)
      puts "Beginning heredoc" if ENV["DEBUG"]
      String.new.tap do |heredoc|
        heredoc << start
        heredoc << "\n"
        loop do
          print "> "
          str = gets
          heredoc << str
          if str =~ /^#{Regexp.escape(marker)}/
            puts "Ending heredoc" if ENV["DEBUG"]
            break
          end
        end
      end
    end

  end
end
