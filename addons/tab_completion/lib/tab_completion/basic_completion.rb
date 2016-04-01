class TabCompletion
  class BasicCompletion
    class << self
      attr_accessor :priority
    end
    self.priority = 1

    attr_reader :world

    def initialize(world:, word_break_characters:, path:nil)
      @world = world
      @word_break_characters = word_break_characters
      path ||= @world.env["PATH"]
      @paths = path.split(":")
    end

    def completions_for(word, words, word_index)
      completions_by_name = {}
      if looking_for_command?(word, words, word_index)
        # Lowest Priority
        completions_by_name.merge! command_completion_matches_for(word, words)

        # Medium Priority
        completions_by_name.merge! builtin_completion_matches_for(word, words)

        # Highest Priority
        completions_by_name.merge! alias_completion_matches_for(word, words)
      else
        completions_by_name.merge! filename_completion_matches_for(word, words)
      end
      completions_by_name.values
    end

    private

    def looking_for_command?(word, words, word_index)
      return true if word_index == 0
      return true if words[word_index - 1] =~ /[;&]/
      false
    end


    def alias_completion_matches_for(word, words)
      @world.aliases.names.each_with_object({}) do |name, result|
        if name =~ /^#{Regexp.escape(word)}/
          result[name] ||=  CompletionResult.new(
            type: :alias,
            text: name
          )
        end
      end
    end

    def builtin_completion_matches_for(word, words)
      @world.builtins.each_with_object({}) do |builtin, result|
        if builtin =~ /^#{Regexp.escape(word)}/
          result[builtin] ||=  CompletionResult.new(
            type: :builtin,
            text: builtin
          )
        end
      end
    end

    def command_completion_matches_for(word, line)
      @paths.each_with_object({}) do |path, matches|
        glob = File.join(path, "#{word}*")
        arr = Dir[glob].select { |path| File.executable?(path) && File.file?(path) }
        arr.map { |path| File.basename(path) }.uniq.each do |command|
          matches[command] = CompletionResult.new(type: :command, text: command)
        end
      end
    end

    def filename_completion_matches_for(word, line)
      glob = "#{word}*"
      glob.gsub!("~", world.env["HOME"])
      Dir.glob(glob, File::FNM_CASEFOLD).map do |path|
        text = path.gsub(filtered_work_break_characters_rgx, '\\\\\1')
        descriptive_text = File.basename(text)
        if File.directory?(path)
          CompletionResult.new(type: :directory, text: text, descriptive_text: descriptive_text)
        elsif File.symlink?(path)
          CompletionResult.new(type: :symlink, text: text, descriptive_text: descriptive_text)
        elsif File.file?(path) && File.executable?(path)
          CompletionResult.new(type: :command, text: text, descriptive_text: descriptive_text)
        else
          CompletionResult.new(type: :file, text: text, descriptive_text: descriptive_text)
        end
      end
    end

    # Remove file separator and the back-slash from word break characters when determining
    # the pre-word-context
    def filtered_word_break_characters
      @word_break_characters.sub(File::Separator, "").sub('\\', '')
    end

    def filtered_work_break_characters_rgx
      /([#{Regexp.escape(filtered_word_break_characters)}])/
    end

  end
end
