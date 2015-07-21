require 'ostruct'

class TabCompletion
  class FileCompletion
    attr_reader :editor

    def initialize(editor:, path:ENV["PATH"])
      @editor = editor
      @paths = path.split(":")
      @word = editor.line.word
      @before_text = editor.line.text[0...@word[:start]]
      @pre_word_text = pre_word_context
    end

    def completions
      command_completion_matches + filename_completion_matches
    end

    private

    def command_completion_matches
      matches = @paths.inject([]) do |matches, path|
        glob = File.join(path, "#{@pre_word_text}#{@word[:text]}*")
        arr = Dir[glob].select { |path| File.executable?(path) && File.file?(path) }
        arr.each { |path| matches << path }
        matches
      end
      matches.map { |path| File.basename(path) }.sort.uniq.map do |command|
        build_result(type: :command, text:command)
      end
    end

    def filename_completion_matches
      glob = "#{@pre_word_text}#{@word[:text]}*"
      Dir.glob(glob, File::FNM_CASEFOLD).map do |path|
        text = path.gsub(filtered_work_break_characters_rgx, '\\\\\1')
        if File.directory?(path)
          build_result(type: :directory, text: text.sub(/^#{Regexp.escape(@pre_word_text)}/, ''))
        else
          build_result(type: :file, text: text.sub(/^#{Regexp.escape(@pre_word_text)}/, ''))
        end
      end
    end

    def build_result(type:, text:)
      OpenStruct.new(type:type, text:text)
    end

    # Remove file separator and the back-slash from word break characters when determining
    # the pre-word-context
    def filtered_word_break_characters
      editor.word_break_characters.sub(File::Separator, "").sub('\\', '')
    end

    def filtered_work_break_characters_rgx
      /([#{Regexp.escape(filtered_word_break_characters)}])/
    end

    # +pre_word_context+ is the "lib/" if the user hits tab after typing "ls lib/"
    # because the current word will be set to ""
    def pre_word_context
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
          else
            str << ch
          end
        end
        str.reverse
      end
    end

  end
end
