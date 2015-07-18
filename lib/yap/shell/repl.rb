require 'shellwords'
require 'term/ansicolor'

module Yap::Shell
  module Color
    extend Term::ANSIColor
  end

  class Repl
    attr_reader :editor

    def initialize(world:nil)
      @world = world
      @editor= world.editor
    end

    def loop_on_input(&blk)
      @blk = blk

      install_default_keybindings
      install_default_tab_completion_proc

      loop do
        heredoc = nil

        begin
          $stdout.flush
          ensure_process_group_controls_the_tty
          input = editor.read(@world.prompt.update.text, true)

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

    def install_default_keybindings
      editor.terminal.keys.merge!(enter: [13])
      editor.bind(:return){ editor.newline }

      editor.bind(:ctrl_g) { editor.clear_history }
      editor.bind(:ctrl_l) { editor.debug_line }
      editor.bind(:ctrl_h) { editor.show_history }
      editor.bind(:ctrl_d) { puts; puts "Exiting..."; exit }
      editor.bind(:ctrl_a) { editor.move_to_position 0 }
      editor.bind(:ctrl_e) { editor.move_to_position editor.line.length }
    end

    def install_default_tab_completion_proc
      editor.completion_proc = lambda do |word|
        Dir["#{word}*"].map{ |str| str.gsub(/ /, '\ ')}
      end
    end

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
        str = editor.read(@world.prompt.update.text, false)
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
