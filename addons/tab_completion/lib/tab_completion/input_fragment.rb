class TabCompletion
  class InputFragment
    attr_reader :line_position, :word, :before_text, :after_text, :pre_word_context, :word_break_characters

    def initialize(line, word_break_characters)
      @word_break_characters = word_break_characters
      @line_position = line.position
      @word = line.word
      @before_text = line.text[0...@word[:start]]
      @after_text = line.text[@word[:end]+1..-1]
      @pre_word_context = determine_pre_word_context
    end

    # Remove file separator and the back-slash from word break characters when determining
    # the pre-word-context
    def filtered_word_break_characters
      @word_break_characters.sub(File::Separator, "").sub('\\', '')
    end

    def filtered_work_break_characters_rgx
      /([#{Regexp.escape(filtered_word_break_characters)}])/
    end

    private

    # +pre_word_context+ is the "lib/" if the user hits tab after typing "ls lib/"
    # because the current word will be set to ""
    def determine_pre_word_context
      if @before_text.length == 0
        ""
      else
        # Work our way backwards thru the text because we can stop as soon as
        # see a word break character rather than having to keep track of them.
        i = @before_text.length
        str = ""
        loop do
          i -= 1
          ch = @before_text[i]
          if ch =~ filtered_work_break_characters_rgx && (i>0 && @before_text[i-1] != '\\')
            break
          elsif i < 0
            break
          else
            str << ch
          end
        end
        str.reverse
      end
    end
  end

end
