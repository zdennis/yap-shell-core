require 'term/ansicolor'

class TabCompletion < Addon
  Color = Term::ANSIColor

  COLOR_PROCS = Hash.new{ |h,k| h[k] = ->{ "" } }.merge(
    directory: -> { Color.bold + Color.red }
  )
  
  POST_DECORATOR_PROCS = Hash.new{ |h,k| h[k] = ->{ "" } }.merge(
    directory: -> { "/" }
  )

  def initialize_world(world)
    @world = world
    @world.editor.bind(:tab){ complete }
  end

  def complete
    matches = [
      OpenStruct.new(type: :directory, text:"lib"),
      OpenStruct.new(type: :directory, text:"Library"),
      OpenStruct.new(type: :file, text:"License.txt"),
      OpenStruct.new(type: :file, text:"legumes")
    ]
    editor = @world.editor

    break_on_bytes = [editor.terminal.keys[:ctrl_c]].flatten

    $z.puts "line: #{editor.line.inspect}"
    @selected_index = nil
    last_printed_text = nil

    t = TermInfo.new ENV["TERM"], editor.output
    $z.puts t.inspect

    loop do
      show_the_user_matches matches, @selected_index

      if @selected_index
        if last_printed_text
          last_printed_text.length.times {
            editor.delete_left_character
          }
        end
        last_printed_text = matches[@selected_index].text

        before_text = editor.line.text[0...editor.line.position]
        after_text = editor.line.text[editor.line.position..-1]
        text = [before_text, last_printed_text, after_text].join
        editor.overwrite_line text
      end

      byte = [editor.read_character].flatten.first

      if break_on_bytes.include?(byte)
        return
      elsif [?\n.ord, ?\r.ord].include?(byte)
        preserve_cursor { editor.clear_screen_down }
        editor.write " "

        # This is so the read loop doesn't think we want to go to the next line of input.
        editor.char = ""
        break
      elsif [?\t.ord].include?(byte)
        @selected_index = @selected_index ? @selected_index+1 : 0
        @selected_index = 0 if @selected_index == matches.length
      end
    end
  end

  def show_the_user_matches(matches, selected_index)
    editor = @world.editor

    if matches.length == 0
      # display the first match as a possible selection
      editor.print matches.first.text
      return
    end

    longest = matches.map(&:text).map(&:length).max
    num_spaces_between = 2

    completions_per_line = editor.terminal_width / (longest + num_spaces_between)
    lines_needed = (matches.length / completions_per_line.to_f).ceil

    cursor_position = editor.cursor_position
    extra_lines_needed = (cursor_position.row + lines_needed) - editor.terminal_height

    $z.puts "extra rows: #{extra_lines_needed}"
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
            match.text,
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
    term_info = TermInfo.new(ENV["TERM"], @world.editor.output)
    term_info.control "sc" # store cursor position
    blk.call
    term_info.control "rc" # restore cursor position
  end

end
