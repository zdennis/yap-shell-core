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
      install_default_keybindings
      install_default_tab_completion_proc
    end

    def on_input(&blk)
      @blk = blk

      @world.editor.on_read_line do |event|
        # editor.history = true?
        line = event[:payload][:line] << "\n"
        begin
          @blk.call(line)
          @world.editor.redraw_prompt
        rescue Yap::Shell::Parser::Lexer::NonterminatedString, Yap::Shell::Parser::Lexer::LineContinuationFound
          line << read_another_line_of_input
          retry
        rescue ::Yap::Shell::CommandUnknownError => ex
          puts "  CommandError: #{ex.message}"
        rescue ::Yap::Shell::Parser::ParseError => ex
          puts "  Parse error: #{ex.message}"
        ensure
          @world.editor.reset_line
        end

        ensure_process_group_controls_the_tty
        @world.refresh_prompt
      end
    end

    private

    def read_another_line_of_input
      print @world.secondary_prompt.update.text
      gets
    end

    def kill_ring
      @kill_ring ||= []
    end

    def install_default_keybindings
      editor.terminal.keys.merge!(enter: [13])
      editor.bind(:return){ editor.newline }

      # Move to beginning of line
      editor.bind(:ctrl_a) { editor.move_to_beginning_of_input }

      # Move to end of line
      editor.bind(:ctrl_e) { editor.move_to_end_of_input }

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
        text = kill_ring[-1]
        if text
          editor.yank_forward text.without_ansi
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
            position = before_text.length - i
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

      editor.bind(:enter) { editor.newline }
      editor.bind(:tab) { editor.complete }
      editor.bind(:backspace) { editor.delete_left_character }

      # Delete to end of line from cursor position
      editor.bind(:ctrl_k) {
        kill_ring.push editor.kill_forward
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

      editor.bind(:ctrl_r) {
        $r = $r ? false : true
        #  editor.redo
      }
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

      # character-search; wraps around as necessary
      editor.bind(:ctrl_n) {
        line = editor.line
        text, start_position = line.text, line.position
        i, new_position = start_position, nil

        break_on_bytes = [editor.terminal.keys[:ctrl_c]].flatten
        byte = [editor.read_character].flatten.first

        unless break_on_bytes.include?(byte)
          loop do
            i += 1
            i = 0 if i >= text.length                                    # wrap-around to the beginning
            break if i == start_position                                 # back to where we started
            (editor.move_to_position(i) ; break) if text[i] == byte.chr  # found a match; move and break
          end
        end
      }
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
      tty_pgrp = Termios.tcgetpgrp(STDIN)
      while ![Process.pid, Process.getpgrp].include?(tty_pgrp)
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
        str = editor.read(@world.secondary_prompt.update.text, false)
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
