class TabCompletion
  class CustomCompletion
    attr_reader :input_fragment

    def initialize(match:nil, &blk)
      @match = match
      @blk = blk
    end

    def new(input_fragment:)
      @input_fragment = input_fragment
      self
    end

    def completions
      if input_fragment.before_text =~ match_rgx
        @blk.call(input_fragment)
      else
        []
      end
    end

    private

    def match_rgx
      return // if @match.nil?
      return @match if @match.is_a?(Regexp)
      /^#{Regexp.escape(@match.to_s)}\s/
    end
  end
end
