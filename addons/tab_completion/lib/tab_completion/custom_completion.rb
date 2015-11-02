class TabCompletion
  class CustomCompletion
    PRIORITY = 2

    attr_reader :name, :pattern, :priority

    def initialize(world:, name:nil, pattern:nil, priority:PRIORITY, &blk)
      @world = world
      @name = name
      @pattern = pattern
      @priority = priority
      @blk = blk
    end

    def new(world:)
      @world = world
      self
    end

    def completions_for(word, line)
      # TODO
      return []
    end

    private

    def match_rgx
      return // if pattern.nil?
      return pattern if pattern.is_a?(Regexp)
      /^#{Regexp.escape(pattern.to_s)}\s/
    end
  end
end
