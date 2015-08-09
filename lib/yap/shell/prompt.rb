require 'yap/shell/event_emitter'

module Yap::Shell
  class PromptRenderer
    include Term::ANSIColor

    attr_reader :editor

    def initialize(text:text, editor:editor)
      @editor = editor
      @term_info = TermInfo.new("xterm-256color", STDOUT)
      @text = text
      #
      # Signal.trap("SIGWINCH") do
      #   # clear to end of line (in case we're shortening the line)
      #   @term_info.control "ed", 1
      #   Readline.redisplay
      # end
    end

    def redraw_prompt(text)
      editor.prompt = text
    end
    #
    # def redraw_right_prompt(text)
    #   @right_text = text
    #
    #   buffer = Readline.line_buffer
    #   left_text_without_ansi = strip_ansi(@text)
    #   total_length = left_text_without_ansi.length + buffer.length
    #
    #   rows, columns = term_info.screen_size
    #
    #   if is_overlapping_right_prompt?(total_length)
    #     preserve_cursor do
    #       term_info.control "cub", columns
    #       term_info.control "cuf", total_length
    #       term_info.control "el", 1 # clear to end of line
    #     end
    #   else
    #     preserve_cursor do
    #       term_info.control "cub", columns
    #       term_info.control "cuf", total_length
    #       term_info.control "el", 1 # clear to end of line
    #     end
    #     _draw_right_prompt(text)
    #   end
    # end

    def _draw_right_prompt(text)
      text_without_ansii = strip_ansi(text)
      rows, columns = term_info.screen_size

      preserve_cursor do
        # cursor backward to ?
        term_info.control "cub", columns
        # if on == :previous_row
        #   term_info.control "cuu", 1
        # end

        @right_prompt_position = columns - text_without_ansii.length

        # cursor forward to where we should start drawing the prompt
        term_info.control "cuf", @right_prompt_position
        term_info.write bright_black(text)
      end
    end

    private

    attr_reader :term_info

    def preserve_cursor(&blk)
      term_info.control "sc" # store cursor position
      blk.call
      term_info.control "rc" # restore cursor position
    end

    def strip_ansi(text)
      text.gsub(/\033\[[0-9;]*m/, "")
    end

    def is_overlapping_right_prompt?(position)
      @right_prompt_position && position >= @right_prompt_position
    end
  end

  class PromptController
    attr_reader :world, :prompt

    def initialize(world:, prompt:)
      @world = world
      @prompt = prompt
      @renderer = PromptRenderer.new(text:prompt.text, editor:world.editor)
      @events = []

      @prompt.on(:immediate_text_update){ |text| @renderer.redraw_prompt text }
      @prompt.on(:text_update){ |text| @events << [:redraw_prompt, text] }
      # @prompt.on(:right_text_update){ |text| @events << [:redraw_right_prompt, text] }

      event_loop
    end

    private

    def event_loop
      @mutex = Mutex.new
      @thr = Thread.new do
        loop do
          sleep 0.25
          while event=@events.pop
            process_event(event)
          end
        end
      end
      @thr.abort_on_exception = true
    end

    def process_event(event)
      # Make sure we're in the foreground otherwise trying Error::EIO will be
      # thrown trying to talk to STDOUT
      if @world.foreground?
        renderer_action, text = event
        begin
          @mutex.synchronize do
            @renderer.send renderer_action, text
          end
        rescue Errno::EIO => ex
          # EIO is still possible in some cases so if it does
          # happen treat it as a no-op since we're not in the
          # foreground.
        end
      end
    end
  end

  class Prompt
    include EventEmitter

    attr_reader :text, :right_text

    def initialize(text:, &blk)
      @text = text
      @blk = blk
    end

    def text=(text)
      @text = text
      emit :text_update, text
    end

    def right_text=(text)
      @right_text = text
      emit :right_text_update, text
    end

    def update
      if @blk
        @text = @blk.call
        emit :immediate_text_update, text
      end
      self
    end
  end
end
