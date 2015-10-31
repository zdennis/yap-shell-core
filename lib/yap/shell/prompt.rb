module Yap::Shell
  class Prompt
    attr_reader :text

    def initialize(text:, &blk)
      @text = text
      @blk = blk
    end

    def text=(text)
      @text = text
    end

    def update
      if @blk
        @text = @blk.call
      end
      self
    end
  end
end
