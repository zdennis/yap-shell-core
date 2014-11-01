require 'ostruct'

module Lagniappe
  class CommandFactory
    def self.build_command_for(command_str)
      case command_str
      when /^\!(.*)/ then RubyCommand.new(str:$1)
      else            ShellCommand.new(str:command_str)
      end
    end
  end

  class ExecutionContext
  end

  class CommandChain < Array
  end

  class CommandPipeline
    def initialize(commands:)
      @commands = commands
      @pipes = []
    end

    def length
      @commands.length
    end

    def each(&blk)
      @pipes.clear
      arr = @commands.map.with_index do |command, n|
        stdin, stdout, stderr = pipes_for_command n:n+1, of: @commands.length
        @pipes << OpenStruct.new(stdin:stdin, stdout:stdout, stderr:stderr)
        [command, stdin, stdout, stderr]
      end

      if block_given?
        arr.each{ |*args| yield *args }
      else
        arr.each
      end
    end

    private

    def pipes_for_command(n:, of:)
      if of == 1    # only one command in the pipeline
        [:stdin, :stdout, :stderr]
      elsif n == 1  # we are the last command, e.g. 'grep' in 'ls | grep e'
        ["fifo-test-#{of - n}", :stdout, :stderr]
      elsif n == of # we are the first command, e.g. 'ls' in 'ls | grep e'
        [:stdin, @pipes.last.stdin, @pipes.last.stdin]
      elsif n < of  # more than one command in the pipeline, w're somewhere in the middle
        ["fifo-test-#{of - n}", @pipes.last.stdin, @pipes.last.stdin]
      end
    end
  end

  module Command
    attr_reader :str

    def initialize(str: str)
      @str = str
    end

    def execution_context
      raise NotImplementedError, ":execution_context must be implemented by including object."
    end
  end

  class ShellCommand
    include Command

    def type
      :ShellCommand
    end

    def to_executable_str
      str.shellsplit.flatten.join " "
    end
  end

  class RubyCommand
    include Command

    def type
      :RubyCommand
    end

    def to_executable_str
      str
    end
  end
end
