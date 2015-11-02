class TabCompletion
  class FileCompletion
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

    def completions_for(word, line)
      completions = []
      if looking_for_command?
        completions.concat command_completion_matches_for(word, line)
      end
      completions.concat filename_completion_matches_for(word, line)
      completions
    end

    private

    def looking_for_command?
      # TODO
      false
    end

    def command_completion_matches_for(word, line)
      matches = @paths.inject([]) do |matches, path|
        glob = "#{path}*"
        arr = Dir[glob].select { |path| File.executable?(path) && File.file?(path) }
        arr.each { |path| matches << path }
        matches
      end

      matches.map { |path| File.basename(path) }.sort.uniq.map do |command|
        CompletionResult.new(type: :command, text:command)
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
