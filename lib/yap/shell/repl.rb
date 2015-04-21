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
          $stdout.flush
          ensure_process_group_controls_the_tty

          input = Readline.readline("#{@world.prompt.update.text}", true)

          next if input == ""

          input = process_heredoc(input)

          yield input
        # rescue Errno::EIO => ex
        #   # This happens when yap is no longer the foreground process
        #   # but it tries to receive input/output from the tty. I believe it
        #   # is a race condition when launching a child process.
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

    # This is to prevent the Errno::EIO error from occurring by ensuring that
    # if we haven't been made the process group controlling the TTY that we
    # become so. This method intentionally blocks.
    def ensure_process_group_controls_the_tty
      while Process.pid != Termios.tcgetpgrp(STDIN)
        Termios.tcsetpgrp(STDIN, Process.pid)
        sleep 0.1
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
