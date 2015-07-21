require 'term/ansicolor'

class TabCompletion < Addon
  require 'tab_completion/input_fragment'
  require 'tab_completion/custom_completion'
  require 'tab_completion/file_completion'

  COMPLETIONS = [ FileCompletion ]

  Color = Term::ANSIColor

  COLOR_PROCS = Hash.new{ |h,k| h[k] = ->{ "" } }.merge(
    directory: -> { Color.bold + Color.red },
    command: -> { Color.bold + Color.green },
    symlink: -> { Color.bold + Color.cyan }
  )

  POST_DECORATOR_PROCS = Hash.new{ |h,k| h[k] = ->{ "" } }.merge(
    directory: -> { "/" },
    symlink: -> { "@" }
  )

  attr_reader :editor

  def initialize_world(world)
    @world = world
    @editor = @world.editor
    @editor.bind(:tab){ complete }
    @completions = COMPLETIONS.dup
    @color_procs = COLOR_PROCS.dup
    @post_decorators = POST_DECORATOR_PROCS.dup
  end

  def add_completion(match:nil, &blk)
    raise ArgumentError, "Must supply block!" unless block_given?
    @completions.push CustomCompletion.new(match:match, &blk)
  end

  def set_decoration(type, &blk)
    raise ArgumentError, "Must supply block!" unless block_given?
    @color_procs[type] = blk
  end

  def complete
    @completion_char = editor.char
    @input_fragment = InputFragment.new(editor.line, editor.word_break_characters)
    @selected_index = nil

    matches = @completions.map do |completion|
      if completion.respond_to?(:call)
        completion.call
      else
        completion.new(input_fragment:@input_fragment).completions
      end
    end.flatten

    cycle_matches matches
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
        display_text = "#{match.text}#{POST_DECORATOR_PROCS[match.type].call}"

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

    preserve_cursor { editor.clear_screen_down }
    editor.process_character
  end

  def show_the_user_matches(matches)
    if matches.length == 1
      @selected_index = 0
      return true
    end

    @longest_match = matches.map(&:text).map(&:length).max
    @num_spaces_between = 2

    @completions_per_line = editor.terminal_width / (@longest_match + @num_spaces_between)
    lines_needed = (matches.length / @completions_per_line.to_f).ceil

    cursor_position = editor.cursor_position
    extra_lines_needed = (cursor_position.row + lines_needed) - editor.terminal_height

    if lines_needed > editor.terminal_height
      preserve_cursor do
        editor.puts
        editor.print "Do you wish to see all #{matches.length} possibilities? "
        editor.read_character
        return false unless [?y.ord, ?Y.ord].include?(editor.char)
      end
      pretty_print_matches(matches)
      editor.overwrite_line editor.line.text
    elsif extra_lines_needed > 0
      (extra_lines_needed + 1).times { editor.puts }
      t = TermInfo.new(ENV["TERM"], editor.output)
      if extra_lines_needed > 0
        editor.print t.control_string("cup", cursor_position.row - (extra_lines_needed + 2), cursor_position.column)
      end
      preserve_cursor{ pretty_print_matches(matches) }
    else
      preserve_cursor{ pretty_print_matches(matches) }
    end

    true
  end

  private

  def pretty_print_matches(matches)
    str = ""
    matches.each.with_index do |match, i|
      str << "\n" if (i % @completions_per_line) == 0
      if @selected_index == i
        str << sprintf("%s%-#{@longest_match}s%s%#{@num_spaces_between}s",
          Color.negative,
          "#{match.text}#{@post_decorators[match.type].call}",
          Color.reset,
          "")
      else
        str << sprintf("%s%-#{@longest_match}s%s%#{@num_spaces_between}s",
          @color_procs[match.type].call,
          "#{match.text}#{@post_decorators[match.type].call}",
          Color.reset,
          "")
      end
    end
    editor.puts str
  end

  def preserve_cursor(&blk)
    term_info = TermInfo.new(ENV["TERM"], editor.output)
    term_info.control "sc" # store cursor position
    blk.call
  ensure
    term_info.control "rc" # restore cursor position
  end
end
