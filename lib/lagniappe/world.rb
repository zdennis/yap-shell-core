require 'term/ansicolor'

module Lagniappe
  class World
    include Term::ANSIColor

    attr_accessor :prompt

    def initialize(options)
      (options || {}).each do |k,v|
        self.send "#{k}=", v
      end
    end
  end
end
