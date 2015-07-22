require 'ostruct'

class TabCompletion
  class FileCompletion
    class << self
      attr_accessor :priority
    end
    self.priority = 1

    def initialize(input_fragment:, path:ENV["PATH"])
      @paths = path.split(":")
      @input_fragment = input_fragment
    end

    def completions
      completions = []
      completions.concat command_completion_matches if looking_for_command?
      completions.concat filename_completion_matches
      completions
    end

    private

    def looking_for_command?
      "#{@input_fragment.pre_word_context}#{@input_fragment.word[:text]}".length == @input_fragment.line_position
    end

    def command_completion_matches
      matches = @paths.inject([]) do |matches, path|
        glob = File.join(path, "#{@input_fragment.pre_word_context}#{@input_fragment.word[:text]}*")
        arr = Dir[glob].select { |path| File.executable?(path) && File.file?(path) }
        arr.each { |path| matches << path }
        matches
      end
      matches.map { |path| File.basename(path) }.sort.uniq.map do |command|
        build_result(type: :command, text:command)
      end
    end

    def filename_completion_matches
      glob = "#{@input_fragment.pre_word_context}#{@input_fragment.word[:text]}*"
      glob.gsub!("~", ENV["HOME"])
      Dir.glob(glob, File::FNM_CASEFOLD).map do |path|
        text = path.gsub(filtered_work_break_characters_rgx, '\\\\\1')
        text.sub!(/^#{Regexp.escape(@input_fragment.pre_word_context)}/, '')
        text = File.basename(text)
        if File.directory?(path)
          build_result(type: :directory, text: text)
        elsif File.symlink?(path)
          build_result(type: :symlink, text: text)
        elsif File.file?(path) && File.executable?(path)
          build_result(type: :command, text: text)
        else
          build_result(type: :file, text: text)
        end
      end
    end

    def build_result(type:, text:)
      OpenStruct.new(type:type, text:text)
    end

    # Remove file separator and the back-slash from word break characters when determining
    # the pre-word-context
    def filtered_word_break_characters
      @input_fragment.word_break_characters.sub(File::Separator, "").sub('\\', '')
    end

    def filtered_work_break_characters_rgx
      /([#{Regexp.escape(filtered_word_break_characters)}])/
    end

  end
end
