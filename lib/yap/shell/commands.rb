require 'shellwords'

module Yap::Shell
  require 'yap/shell/aliases'
  require 'yap/shell/execution/result'

  class CommandError < StandardError ; end

  class CommandFactory
    def self.build_command_for(world:, command:, args:, heredoc:, internally_evaluate:, line:)
      return RubyCommand.new(world:world, str:command) if internally_evaluate

      case command
      when ShellCommand then ShellCommand.new(world:world, str:command, args:args, heredoc:heredoc, line:line)
      when BuiltinCommand then BuiltinCommand.new(world:world, str:command, args:args, heredoc:heredoc)
      when FileSystemCommand then FileSystemCommand.new(world:world, str:command, args:args, heredoc:heredoc)
      else
        UnknownCommand.new(world:world, str:command, args:args, heredoc:heredoc)
      end
    end
  end

  class Command
    attr_accessor :world, :str, :args, :line
    attr_accessor :heredoc

    def initialize(world:, str:, args:[], line:nil, heredoc:nil)
      @world = world
      @str = str
      @args = args
      @heredoc = heredoc
      @line = line
    end

    def to_s
      "#{self.class.name}(#{str.inspect})"
    end
    alias :to_str :to_s
    alias :inspect :to_s

    def to_executable_str
      raise NotImplementedError, ":to_executable_str must be implemented by including object."
    end
  end

  class BuiltinCommand < Command
    def self.===(other)
      self.builtins.keys.include?(other.split(' ').first.to_sym) || super
    end

    def self.builtins
      @builtins ||= {
        builtins: lambda { |stdout:, **| stdout.puts @builtins.keys.sort },
        exit: lambda { |code = 0, **| exit(code.to_i) },
        fg: lambda{ |**| :resume },
      }
    end

    def self.add(command, &action)
      builtins.merge!(command.to_sym => action)
    end

    def execute(stdin:, stdout:, stderr:)
      action = self.class.builtins.fetch(str.to_sym){ raise("Missing proc for builtin: '#{builtin}' in #{str.inspect}") }
      action.call world:world, args:args, stdin:stdin, stdout:stdout, stderr:stderr
    end

    def type
      :BuiltinCommand
    end

    def to_executable_str
      raise NotImplementedError, "#to_executable_str is not implemented on BuiltInCommand"
    end
  end

  class UnknownCommand < Command
    EXIT_CODE = 127

    def execute(stdin:, stdout:, stderr:)
      stderr.puts "yap: command not found: #{str}"
      EXIT_CODE
    end

    def type
      :BuiltinCommand
    end
  end

  class FileSystemCommand < Command
    def self.world
      ::Yap::World.instance
    end

    def self.===(other)
      command = other.split(/\s+/).detect{ |f| !f.include?("=") }

      # Check to see if the user gave us a valid path to execute
      return true if File.executable?(command)

      # See if the command exists anywhere on the path
      world.env["PATH"].split(":").detect do |path|
        File.executable?(File.join(path, command))
      end
    end

    def type
      :FileSystemCommand
    end

    def to_s
      "#{self.class.name}(#{to_executable_str.inspect})"
    end
    alias :to_str :to_s
    alias :inspect :to_s

    def to_executable_str
      [
        str,
        args.join(' ')
      ].join(' ')
    end
  end

  class ShellCommand < Command
    def self.registered_functions
      (@registered_functions ||= {}).freeze
    end

    def self.define_shell_function(name_or_pattern, name: nil, &blk)
      raise ArgumentError, "Must provide block when defining a shell function" unless blk
      name_or_pattern = name_or_pattern.to_s if name_or_pattern.is_a?(Symbol)
      (@registered_functions ||= {})[name_or_pattern] = blk
    end

    def self.===(command)
      registered_functions.detect do |name_or_pattern, *_|
        name_or_pattern.match(command)
      end
    end

    def type
      :ShellCommand
    end

    def to_proc
      self.class.registered_functions.detect do |name_or_pattern, function_body|
        return function_body if name_or_pattern.match(str)
      end
      raise "Shell function #{str} was not found!"
    end
  end

  class RubyCommand < Command
    def type
      :RubyCommand
    end

    def to_executable_str
      str
    end
  end
end
