module Lagniappe
  class CommandFactory
    def self.build_command_for(str)
      case str
      when /^\!/ then RubyCommand.new(str)
      else            ShellCommand.new(str)
      end
    end
  end

  class CommandChain
    include Enumerable

    def initialize
      @chain = []
    end

    def each(&blk)
      @chain.each(&blk)
    end

    def push(command)
      @chain << command
    end
    alias_method :<<, :push

    def reverse
      @chain.reverse
    end

    def length
      @chain.length
    end
  end

  class ShellCommand
    def initialize(body)
      @body = body
    end

    def to_executable_str
      @body.shellsplit.flatten.join " "
    end
  end

  class RubyCommand
    def initialize(body)
      @body = body
    end

    def to_executable_str
      @body
    end
  end
end
