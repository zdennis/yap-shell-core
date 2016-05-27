class HistorySearch < Addon
  attr_reader :editor

  def initialize_world(world)
    @editor = world.editor
  end

  def prompt_user_to_search
    label_text = "(reverse-search): "
    search_label = ::TerminalLayout::Box.new(
      content: label_text,
      style: {
        display: :inline,
        height: 1
      }
    )
    search_box = ::TerminalLayout::InputBox.new(
      content: "",
      style: {
        display: :inline,
        height: 1
      }
    )
    search_box.name = "focused-input-box"

    Treefell['shell'].puts "editor.content_box.children: #{editor.content_box.children.inspect}"
    history_search_env = editor.new_env
    history_search = Search.new(editor.history,
      line: ::RawLine::LineEditor.new(::RawLine::Line.new, sync_with: -> { search_box }),
      keys: history_search_env.keys,
      search: -> (term:, result:){
        # when there is no match, result will be nil, #to_s clears out the content
        editor.input_box.content = result.to_s
      },
      done: -> (execute:, result:){
        editor.content_box.children = []
        editor.pop_env
        editor.focus_input_box(editor.input_box)
        editor.overwrite_line(result.to_s)
        editor.process_line if execute
      }
    )

    editor.push_env history_search_env
    editor.push_keyboard_input_processor(history_search)

    editor.content_box.children = [search_label, search_box]
    editor.focus_input_box(search_box)
  end

  class Search
    attr_reader :keys

    def initialize(history, keys:, line:, search:, done:)
      @history = history
      @keys = keys
      @line = line
      @search_proc = search || -> {}
      @done_proc = done || -> {}

      initialize_key_bindings
    end

    def initialize_key_bindings
      @keys.bind(:return){ execute }
      @keys.bind(:ctrl_j){ accept }
      @keys.bind(:ctrl_r){ search_again_backward }
      @keys.bind(:ctrl_n){ search_again_forward }
      @keys.bind(:ctrl_a){ @line.move_to_beginning_of_input }
      @keys.bind(:ctrl_e){ @line.move_to_end_of_input }
      @keys.bind(:backspace) do
        @line.delete_left_character
        perform_search(type: @last_search_was)
      end
      @keys.bind(:escape){ cancel }
      @keys.bind(:ctrl_c){ cancel }
    end

    def read_bytes(bytes)
      if bytes.any?
        Treefell['shell'].puts "history search found bytes: #{bytes.inspect}"

        # [1,2,3] => try 1,2,3 first ,then 1,2, then 1, then move on
        nbytes = bytes.dup
        search_bytes = []
        loop do
          if nbytes.empty?
            break
          elsif @keys[nbytes]
            Treefell['shell'].puts "history search found key-binding for bytes=#{nbytes.inspect}"
            @keys[nbytes].call
            nbytes = search_bytes
            search_bytes = []
          else
            search_bytes.unshift nbytes[-1]
            nbytes = nbytes[0..-2]
          end
        end

        if search_bytes.any?
          Treefell['shell'].puts "history searching with bytes=#{bytes.inspect}"
          search_with_bytes(bytes)
        end
      end
    end

    private

    def accept
      @done_proc.call(execute: false, result: result)
    end

    def cancel
      @done_proc.call(execute: false, result: result)
    end

    def execute
      @done_proc.call(execute: true, result: result)
    end

    def found_match(result:)
      @search_proc.call(term: @line.text, result: result)
    end

    def no_match_found
      @last_match_index = nil
      @search_proc.call(term: @line.text, result: result)
    end

    def result
      @history2search[@last_match_index] if @last_match_index
    end

    def search_again_backward
      Treefell['shell'].puts "history searching again backward"
      if @last_search_was == :forward
        @last_match_index = @history.length - @last_match_index - 1
        @history2search = @history.reverse
      end
      perform_search(starting_index: @last_match_index, type: :backward)
    end

    def search_again_forward
      Treefell['shell'].puts "history searching again forward"
      if @last_search_was == :backward
        @last_match_index = @history.length - @last_match_index - 1
        @history2search = @history
      end
      perform_search(starting_index: @last_match_index, type: :forward)
    end

    def search_with_bytes(bytes)
      part = bytes.map(&:chr).join
      @line.write(part.scan(/[[:print:]]/).join)
      @history2search = @history.reverse
      perform_search(type: :backward)
    end

    def perform_search(starting_index: -1, type:)
      if @line.text.empty?
        no_match_found
        return
      end

      # fuzzy search
      characters = @line.text.split('').map { |ch| Regexp.escape(ch) }
      fuzzy_search_regex = /#{characters.join('.*?')}/

      # non-fuzzy-search
      # fuzzy_search_regex = /#{Regexp.escape(@line.text)}/

      Treefell['shell'].puts "history search matching on regex=#{fuzzy_search_regex.inspect} starting_index=#{starting_index}"
      @last_search_was = type

      match = @history2search.detect.with_index do |item, i|
        next if i <= starting_index

        # Treefell['shell'].puts "history search matching #{(item + @line.text).inspect} =~ #{fuzzy_search_regex}"
        md = (item + @line.text).match(fuzzy_search_regex)
        if md && md.end(0) <= item.length
          # Treefell['shell'].puts "history search match #{item} at #{i}"
          @last_match_index = i
        end
      end

      if match
        found_match(result: match)
      else
        no_match_found
      end
    end
  end
end
