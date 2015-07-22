class TabCompletion
  class CustomCompletion
    PRIORITY = 2

    attr_reader :name, :pattern, :input_fragment, :priority

    def initialize(name:nil, pattern:nil, priority:PRIORITY, &blk)
      @name = name
      @pattern = pattern
      @priority = priority
      @blk = blk
    end

    def new(input_fragment:)
      @input_fragment = input_fragment
      self
    end

    def completions
      md = input_fragment.before_text.match(match_rgx)
      if md
        @blk.call(input_fragment, md)
      else
        []
      end
    end

    private

    def match_rgx
      return // if pattern.nil?
      return pattern if pattern.is_a?(Regexp)
      /^#{Regexp.escape(pattern.to_s)}\s/
    end
  end
end
