require 'term/ansicolor'

class TabCompletion < Addon
  require 'tab_completion/dsl_methods'
  require 'tab_completion/input_fragment'
  require 'tab_completion/custom_completion'
  require 'tab_completion/file_completion'

  COMPLETIONS = [ FileCompletion ]

  Color = Term::ANSIColor

  DISPLAY_PROCS = Hash.new{ |h,k| h[k] = ->(text){ text } }.merge(
    directory: -> (text){ text + "/" }
  )

  STYLE_PROCS = Hash.new{ |h,k| h[k] = ->(text){ text } }.merge(
    directory: -> (text){ Color.bold(Color.red(text)) },
    command:   -> (text){ Color.bold(Color.green(text)) },
    symlink:   -> (text){ Color.bold(Color.cyan(text)) },
    selected:  -> (text){ Color.negative(text) }
  )

  DECORATION_PROCS = Hash.new{ |h,k| h[k] = ->(text){ text } }.merge(
    directory: -> (text){ text + "/" },
    command:   -> (text){ text + "@" }
  )

  attr_reader :editor, :world

  def initialize_world(world)
    @world = world
    @world.extend TabCompletion::DslMethods
    @editor = @world.editor
    @editor.bind(:tab){ complete }
    @completions = COMPLETIONS.dup

    @style_procs = STYLE_PROCS.dup
    @decoration_procs = DECORATION_PROCS.dup
    @display_procs = DISPLAY_PROCS.dup
  end

  def add_completion(name, pattern, &blk)
    raise ArgumentError, "Must supply block!" unless block_given?
    @completions.push CustomCompletion.new(name:name, pattern:pattern, world:world, &blk)
  end

  def set_decoration(type, &blk)
    raise ArgumentError, "Must supply block!" unless block_given?
    @style_procs[type] = blk
  end

  def complete
    @completion_char = editor.char
    @input_fragment = InputFragment.new(editor.line, editor.word_break_characters)
    @selected_index = nil

    matches = @completions.sort_by(&:priority).reverse.map do |completion|
      if completion.respond_to?(:call)
        completion.call
      else
        completion.new(world:@world, input_fragment:@input_fragment).completions
      end
    end.flatten

    matches.each do |match|
      match.descriptive_text = match.text unless match.descriptive_text
    end

    common_string = common_starting_string_amongst_all_matches(matches)
    if common_string
      pos = @input_fragment.line_position
      modified_before_text = @input_fragment.before_text[0...(@input_fragment.line_position - @input_fragment.word[:text].length)]
      text = [modified_before_text, common_string, @input_fragment.after_text].join
      editor.overwrite_line text, @input_fragment.before_text.length + common_string.length
      @input_fragment = InputFragment.new(editor.line, editor.word_break_characters)
    end

    cycle_matches matches
  end

  def common_starting_string_amongst_all_matches(matches)
    common_string = matches.map(&:text).inject do |common_string, string|
      while common_string != string[0...common_string.length]
        common_string = common_string.chop
      end
      common_string
    end
    return nil if common_string.to_s.length == 0
    common_string
  end

  def cycle_matches(matches)
    return if matches.empty?

    @selected_index = nil
    last_printed_text = nil

    loop do
      if @selected_index
        if last_printed_text
          last_printed_text.length.times { editor.delete_left_character }
        end
        match = matches[@selected_index]
        display_text = display_text_for_match(match)

        modified_before_text = @input_fragment.before_text[0...(@input_fragment.line_position - @input_fragment.word[:text].length)]
        text = [modified_before_text, display_text, @input_fragment.after_text].join
        editor.overwrite_line text

        last_printed_text = display_text
      end

      displayed = show_the_user_matches matches
      unless displayed
        editor.char = ""
        break
      end

      @selected_index ||= -1

      editor.read_character
      if [editor.terminal.keys[:return], editor.terminal.keys[:newline]].include?(editor.char)
        # This is so we don't have a valid character to process. This keeps the user
        # at the current line, essentially like they said "I want this match, but don't execute the command yet"
        editor.char = ""
        break
      elsif editor.terminal.keys[:left_arrow] == editor.char
        @selected_index = matches.length if @selected_index == 0
        @selected_index -= 1
      elsif [editor.terminal.keys[:right_arrow], @completion_char].include?(editor.char)
        @selected_index += 1
        @selected_index = 0 if @selected_index == matches.length
      elsif @completion_char != editor.char
        break
      end
    end

    editor.move_to_end_of_line
    preserve_cursor { editor.clear_screen_down }
    editor.process_character
  end

  def show_the_user_matches(matches)
    if matches.length == 1
      @selected_index = 0
      return true
    end

    styled_matches = matches.each.map.with_index do |match, i|
      if @selected_index == i
        style_text_for_selected_match(match)
      else
        style_text_for_nonselected_match(match)
      end
    end

    terminal_width = editor.terminal_width
    terminal_height = editor.terminal_height

    styled_matches.map!{|styled_match| truncate_ansi_text(styled_match) }
    @longest_match = styled_matches.map{ |m| Color.uncolored(m).length }.max

    if @longest_match >= terminal_width
      @longest_match = terminal_width
      @num_spaces_between = 0
    else
      @num_spaces_between = 2
    end

    @completions_per_line = terminal_width / (@longest_match + @num_spaces_between)
    lines_needed = (matches.length / @completions_per_line.to_f).ceil

    cursor_position = editor.cursor_position
    extra_lines_needed = (cursor_position.row + lines_needed) - terminal_height

    if lines_needed > terminal_height
      preserve_cursor do
        editor.puts
        editor.print "Do you wish to see all #{matches.length} possibilities? "
        editor.read_character
        return false unless [?y.ord, ?Y.ord].include?(editor.char)
      end
      pretty_print_matches(styled_matches)
      editor.overwrite_line editor.line.text
    elsif extra_lines_needed > 0
      (extra_lines_needed + 1).times { editor.puts }
      t = TermInfo.new(ENV["TERM"], editor.output)
      if extra_lines_needed > 0
        editor.print t.control_string("cup", cursor_position.row - (extra_lines_needed + 2), cursor_position.column)
        editor.print t.control_string "el"
        editor.print t.control_string "el1"
        editor.print t.control_string("hpa", 0)
        editor.print editor.line.prompt, editor.line.text
        editor.clear_screen_down
      end
      preserve_cursor{ pretty_print_matches(styled_matches) }
    else
      preserve_cursor{ pretty_print_matches(styled_matches) }
    end

    #
    # If a new row was added because the selection was on a long match that wrapped
    # the line then we need to move the cursor up.
    #
    cursor_position = editor.cursor_position
    additional_lines_needed = (editor.line.length + editor.line.prompt.length) / terminal_width
    cursor_rows_moved_up = (cursor_position.row + lines_needed + additional_lines_needed) - terminal_height
    if cursor_rows_moved_up >= 1
      t = TermInfo.new(ENV["TERM"], editor.output)
      cursor_rows_moved_up.times { t.control "cuu1" }
    end

    true
  end

  private

  def pretty_print_matches(styled_matches)
    str = ""
    styled_matches.each.with_index do |styled_match, i|
      str << "\n" if (i % @completions_per_line) == 0
      text = truncate_ansi_text(styled_match)
      str << text
      (@longest_match - Color.uncolored(text).length).times { str << " " }
      @num_spaces_between.times { str << " " }
    end
    editor.puts str
  end

  def display_text_for_match(match)
    @display_procs[match.type].call(match.text.dup)
  end

  def style_text_for_selected_match(match)
    styled_text = @style_procs[match.type].call(match.descriptive_text.dup).to_s
    styled_text = @decoration_procs[match.type].call(styled_text).to_s
    uncolored_text = Color.uncolored(styled_text)
    @style_procs[:selected].call(uncolored_text).to_s
  end

  def style_text_for_nonselected_match(match)
    @decoration_procs[match.type].call(
      @style_procs[match.type].call(match.descriptive_text.dup).to_s
    )
  end

  # Takes a given piece of text that may have ANSI escape sequences and truncates
  # the non-ANSI text while leaving the ANSI sequences in the proper places.
  def truncate_ansi_text(text)
    terminal_width = editor.terminal_width
    if Color.uncolored(text).length >= terminal_width
      # elements 0, 2, 4 are text whereas 1 and 3 are ansi escape sequences
      truncated_text = ""
      width = 0

      text.scan(/(.*?)(\033\[[0-9;]*m)(.*?)(\033\[[0-9;]*m)|(.*)/).each do |t1, ansi1, t2, ansi2, t3|
        t1, ansi1, t2, ansi2, t3 = t1.to_s, ansi1.to_s, t2.to_s, ansi2.to_s, t3.to_s

        t1width = terminal_width - (width + t1.length)
        if t1width >= 0 # we have room to spare
          truncated_text << t1
          width += t1.length
        else            # truncate by however many we were over by
          text2add = t1[0...t1width]
          truncated_text << text2add
          width += text2add.length
        end
        truncated_text << ansi1

        t2width = terminal_width - (width + t2.length)
        if t2width >= 0 # we have room to spare
          truncated_text << t2
          width += t2.length
        else            # truncate by however many we were over by
          text2add = t2[0...t2width]
          truncated_text << text2add
          width += text2add.length
        end
        truncated_text << ansi2

        t3width = terminal_width - (width + t3.length)
        if t3width >= 0 # we have room to spare
          truncated_text << t3
          width += t3.length
        else            # truncate by however many we were over by
          text3add = t3[0...t2width]
          truncated_text << text2add
          width += text2add.length
        end
      end
      truncated_text
    else
      text
    end
  end

  def preserve_cursor(&blk)
    term_info = TermInfo.new(ENV["TERM"], editor.output)
    term_info.control "sc" # store cursor position
    blk.call
  ensure
    term_info.control "rc" # restore cursor position
  end
end
