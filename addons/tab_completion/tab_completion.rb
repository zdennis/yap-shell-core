require 'term/ansicolor'

class TabCompletion < Addon
  Color = Term::ANSIColor

  COLOR_PROCS = Hash.new{ |h,k| h[k] = ->{ "" } }.merge(
    directory: -> { Color.bold + Color.red }
  )

  POST_DECORATOR_PROCS = Hash.new{ |h,k| h[k] = ->{ "" } }.merge(
    directory: -> { "/" }
  )

  attr_reader :editor

  def initialize_world(world)
    @world = world
    @editor = @world.editor
    @editor.bind(:tab){ complete }
  end

  def complete
    @completion_char = editor.char

    @word = editor.line.word
    @user_position = editor.line.position
    @before_text = editor.line.text[0...@word[:start]]
    @after_text = editor.line.text[@word[:end]..-1]
    @pre_word_text = pre_word_context
    @selected_index = nil

    matches = get_filename_completion_matches
    cycle_matches matches
  end

  # +pre_word_context+ is the "lib/" if the user hits tab after typing "ls lib/"
  # because the current word will be set to ""
  def pre_word_context
    # Work our way backwards thru the text because we can stop as soon as
    # see a word break character rather than having to keep track of them.
    i = @before_text.length
    str = ""
    loop do
      i -= 1
      ch = @before_text[i]
      if ch =~ filtered_work_break_characters_rgx && (i>0 && @before_text[i-1] != '\\')
        break
      else
        str << ch
      end
    end
    str.reverse
  end

  def get_filename_completion_matches
    glob = "#{@pre_word_text}#{@word[:text]}*"
    Dir.glob(glob, File::FNM_CASEFOLD).map do |path|
      text = path.gsub(filtered_work_break_characters_rgx, '\\\\\1')
      if File.directory?(path)
        OpenStruct.new(type: :directory, text: text.sub(/^#{Regexp.escape(@pre_word_text)}/, ''))
      else
        OpenStruct.new(type: :file, text: text.sub(/^#{Regexp.escape(@pre_word_text)}/, ''))
      end
    end
  end

  def cycle_matches(matches)
    return if matches.empty?

    @selected_index = nil
    last_printed_text = nil

    while editor.char == @completion_char do
      if @selected_index
        if last_printed_text
          last_printed_text.length.times {
            editor.delete_left_character
          }
        end
        match = matches[@selected_index]
        display_text = "#{match.text}#{POST_DECORATOR_PROCS[match.type].call}"

        modified_before_text = @before_text[0...(@user_position - @word[:text].length)]
        text = [modified_before_text, display_text, @after_text].join
        editor.overwrite_line text

        last_printed_text = display_text
      end

      show_the_user_matches matches, @selected_index

      @selected_index = @selected_index ? @selected_index+1 : 0
      @selected_index = 0 if @selected_index == matches.length
      editor.read_character
      if [editor.terminal.keys[:return], editor.terminal.keys[:newline]].include?(editor.char)
        # This is so we don't have a valid character to process. This keeps the user
        # at the current line, essentially like they said "I want this match, but don't execute the command yet"
        editor.char = ""
        break
      end
    end

    preserve_cursor { editor.clear_screen_down }
    editor.process_character
  end

  def show_the_user_matches(matches, selected_index)
    if matches.length == 1
      @selected_index = 0
      return
    end

    longest = matches.map(&:text).map(&:length).max
    num_spaces_between = 2

    completions_per_line = editor.terminal_width / (longest + num_spaces_between)
    lines_needed = (matches.length / completions_per_line.to_f).ceil

    cursor_position = editor.cursor_position
    extra_lines_needed = (cursor_position.row + lines_needed) - editor.terminal_height

    (extra_lines_needed + 1).times { editor.puts }

    t = TermInfo.new(ENV["TERM"], editor.output)
    if extra_lines_needed > 0
      editor.print t.control_string("cup", cursor_position.row - (extra_lines_needed + 2), cursor_position.column)
    end

    preserve_cursor do
      str = ""
      matches.each.with_index do |match, i|
        str << "\n" if (i % completions_per_line) == 0
        if selected_index == i
          str << sprintf("%s%-#{longest}s%s%#{num_spaces_between}s",
            Color.negative,
            "#{match.text}#{POST_DECORATOR_PROCS[match.type].call}",
            Color.reset,
            "")
        else
          str << sprintf("%s%-#{longest}s%s%#{num_spaces_between}s",
            COLOR_PROCS[match.type].call,
            "#{match.text}#{POST_DECORATOR_PROCS[match.type].call}",
            Color.reset,
            "")
        end
      end
      editor.puts str
    end
  end

  private

  def preserve_cursor(&blk)
    term_info = TermInfo.new(ENV["TERM"], editor.output)
    term_info.control "sc" # store cursor position
    blk.call
    term_info.control "rc" # restore cursor position
  end

  # Remove file separator and the back-slash from word break characters when determining
  # the pre-word-context
  def filtered_word_break_characters
    editor.word_break_characters.sub(File::Separator, "").sub('\\', '')
  end

  def filtered_work_break_characters_rgx
    /([#{Regexp.escape(filtered_word_break_characters)}])/
  end

end
