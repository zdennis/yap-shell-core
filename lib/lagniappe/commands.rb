require 'ostruct'

module Lagniappe
  class CommandError < StandardError ; end
  class CommandUnknownError < CommandError ; end

  class CommandFactory
    def self.build_command_for(command_str)
      case command_str
      when /^\!(.*)/      then RubyCommand.new(str:$1)
      when BuiltinCommand then BuiltinCommand.new(str:command_str)
      when FileSystemCommand  then FileSystemCommand.new(str:command_str)
      # else                     ShellCommand.new(str:command_str)
      else
        raise CommandUnknownError, "Don't know how to execute command: #{command_str}"
      end
    end
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
    attr_accessor :heredoc

    def initialize(str: str, heredoc:heredoc)
      @str = str
      @heredoc = heredoc
    end

    def to_executable_str
      raise NotImplementedError, ":to_executable_str must be implemented by including object."
    end
  end

  class BuiltinCommand
    include Command

    def self.===(other)
      self.builtins.keys.include?(other.split(' ').first.to_sym) || super
    end

    def self.builtins
      @builtins ||= {
        exit: lambda { |code = 0| exit(code.to_i) },
        fg: lambda{ :resume },
        cd: lambda{ |path=ENV['HOME'], *_| Dir.chdir(path) }
        # 'set' => lambda { |args|
        #   key, value = args.split('=')
        #   ENV[key] = value
        # }
      }
    end

    def self.add(command, &action)
      builtins.merge!(command.to_sym => action)
    end

    def execute
      command, *args = Shellwords.split(@str)
      self.class.builtins[command.to_sym].call(*args) || raise("Missing proc for builtin #{@str}")
    end

    def type
      :BuiltinCommand
    end

    def to_executable_str
      raise NotImplementedError, "#to_executable_str is not implemented on BuiltInCommand"
    end
  end

  class FileSystemCommand
    include Command

    def self.===(other)
      command = other.split(/\s+/).detect{ |f| !f.include?("=") }

      # Check to see if the user gave us a valid path to execute
      return true if File.executable?(command)

      # See if the command exists anywhere on the path
      ENV["PATH"].split(":").detect do |path|
        File.executable?(File.join(path, command))
      end
    end

    def type
      :FileSystemCommand
    end

    def to_executable_str
      str
    end
  end

  class ShellCommand
    include Command

    def type
      :ShellCommand
    end

    def to_executable_str
      str.shellescape.shellsplit.flatten.join " "
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
