require 'terminfo'
require 'yap/line/parser'

module Lagniappe
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

          # arr = input.scan(/^(.*?)(<<(-)?(\S+)\s*)?$/).flatten
          # statements, heredoc_start, heredoc_allow_whitespace, heredoc_end_marker = arr
          #
          # if heredoc_start
          #   heredoc = process_heredoc start:heredoc_start, marker: heredoc_end_marker
          # else
          #   # arr = input.scan().flatten
          # end

          line = Line.new(statements, heredoc:heredoc)
          yield line.commands if block_given?
        rescue ::Lagniappe::CommandUnknownError => ex
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
