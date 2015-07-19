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

    def kill_ring
      @kill_ring ||= []
    end

    def install_default_keybindings
      editor.terminal.keys.merge!(enter: [13])
      editor.bind(:return){ editor.newline }

      # Move to beginning of line
      editor.bind(:ctrl_a) { editor.move_to_position 0 }

      # Move to end of line
      editor.bind(:ctrl_e) { editor.move_to_position editor.line.length }

      # Move backward one word at a time
      editor.bind(:ctrl_b) {
        text = editor.line.text[0...editor.line.position].reverse
        position = text.index(/\s+/, 1)
        position = position ? (text.length - position) : 0
        editor.move_to_position position
      }

      # Move forward one word at a time
      editor.bind(:ctrl_f) {
        text = editor.line.text
        position = text.index(/\s+/, editor.line.position)
        position = position ? (position + 1) : text.length
        editor.move_to_position position
      }

      # Yank text from the kill ring and insert it at the cursor position
      editor.bind(:ctrl_y){
        yanked_text = kill_ring[-1]
        if yanked_text
          before_text =  editor.line.text[0...editor.line.position]
          after_text = editor.line.text[editor.line.position..-1]
          text = [before_text, yanked_text, after_text].join
          position = editor.line.position + yanked_text.length
          editor.overwrite_line text
          editor.move_to_position position
        end
      }

      # Backwards delete one word
      editor.bind(:ctrl_w){
        before_text =  editor.line.text[0...editor.line.position]
        after_text = editor.line.text[editor.line.position..-1]

        have_only_seen_whitespace = true
        position = 0

        before_text.reverse.each_char.with_index do |ch, i|
          if ch =~ /\s/ && !have_only_seen_whitespace
            position = before_text.length - (i + 1)
            break
          else
            have_only_seen_whitespace = false
          end
        end

        killed_text = before_text[position...editor.line.position]
        kill_ring.push killed_text

        text = [before_text.slice(0, position), after_text].join
        editor.overwrite_line text
        editor.move_to_position position
      }

      # History forward, but if at the end of the history then give user a
      # blank line rather than remain on the last command
      editor.bind(:down_arrow) {
        if editor.history.searching? && !editor.history.end?
          editor.history_forward
        else
          editor.overwrite_line ""
        end
      }
      editor.bind(:up_arrow) { editor.history_back }

      editor.bind(:enter) { editor.newline }
      editor.bind(:tab) { editor.complete }
      editor.bind(:backspace) { editor.delete_left_character }

      # Delete to end of line from cursor position
      editor.bind(:ctrl_k) {
        kill_ring.push editor.line.text[editor.line.position..-1]
        editor.overwrite_line editor.line.text[0...editor.line.position]
        editor.move_to_position editor.line.length
      }

      # Delete to beginning of line from cursor position
      editor.bind(:ctrl_u) {
        kill_ring.push editor.line.text[0...editor.line.position]
        editor.overwrite_line editor.line.text[editor.line.position..-1]
        editor.move_to_position 0
      }

      # Forward delete a character, leaving the cursor in place
      editor.bind("\e[3~") {
        before_text =  editor.line.text[0...editor.line.position]
        after_text = editor.line.text[(editor.line.position+1)..-1]
        text = [before_text, after_text].join
        position = editor.line.position
        editor.overwrite_line text
        editor.move_to_position position
      }

      editor.bind(:ctrl_l){
        editor.clear_screen
      }

      editor.bind(:ctrl_r) { editor.redo }
      editor.bind(:left_arrow) { editor.move_left }
      editor.bind(:right_arrow) { editor.move_right }
      editor.bind(:up_arrow) { editor.history_back }
      editor.bind(:down_arrow) { editor.history_forward }
      editor.bind(:delete) { editor.delete_character }
      editor.bind(:insert) { editor.toggle_mode }

      editor.bind(:ctrl_g) { editor.clear_history }
      # editor.bind(:ctrl_l) { editor.debug_line }
      editor.bind(:ctrl_h) { editor.show_history }
      editor.bind(:ctrl_d) { puts; puts "Exiting..."; exit }

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
