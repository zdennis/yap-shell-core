class TabCompletion
  module DslMethods
    def tab_completion(name, pattern, &blk)
      self[:tab_completion].add_completion(name, pattern, &blk)
    end
  end
end
