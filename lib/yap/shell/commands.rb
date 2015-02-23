require 'shellwords'
require 'yap/shell/aliases'

module Yap::Shell
  class CommandError < StandardError ; end
  class CommandUnknownError < CommandError ; end

  class CommandFactory
    def self.build_command_for(command:, args:, heredoc:, internally_evaluate:)
      return RubyCommand.new(str:command) if internally_evaluate

      case command
      when ShellCommand then ShellCommand.new(str:command, args:args, heredoc:heredoc)
      when BuiltinCommand then BuiltinCommand.new(str:command, args:args, heredoc:heredoc)
      when FileSystemCommand  then FileSystemCommand.new(str:command, args:args, heredoc:heredoc)
      else
        raise CommandUnknownError, "Don't know how to execute command: #{command}"
      end
    end
  end

  class Command
    attr_accessor :str, :args
    attr_accessor :heredoc

    def initialize(str:, args:[], heredoc:nil)
      @str = str
      @args = args
      @heredoc = heredoc
    end

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
        builtins: lambda { puts @builtins.keys.sort },
        exit: lambda { |code = 0| exit(code.to_i) },
        fg: lambda{ :resume },
        # cd: lambda{ |path=ENV['HOME'], *_| Dir.chdir(path) }
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
      action = self.class.builtins.fetch(str.to_sym){ raise("Missing proc for builtin: '#{builtin}' in #{str.inspect}") }
      action.call *args
    end

    def type
      :BuiltinCommand
    end

    def to_executable_str
      raise NotImplementedError, "#to_executable_str is not implemented on BuiltInCommand"
    end
  end

  class FileSystemCommand < Command
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
      [
        str,
        args.map(&:shellescape).join(' ')
      ].join(' ')
    end
  end

  class ShellCommand < Command
    def self.registered_functions
      (@registered_functions ||= {}).freeze
    end

    def self.define_shell_function(name, &blk)
      raise ArgumentError, "Must provided block when defining a shell function" unless blk
      (@registered_functions ||= {})[name.to_sym] = blk
    end

    def self.===(other)
      registered_functions.include?(other.to_sym)
    end

    def type
      :ShellCommand
    end

    def to_proc
      self.class.registered_functions.fetch(str.to_sym){
        raise "Shell function #{str} was not found!"
      }
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
