require "lagniappe/version"

module Lagniappe
  autoload :Console, "lagniappe/console"
  autoload :Shell,   "lagniappe/shell"
  autoload :World,   "lagniappe/world"

  autoload :Repl,           "lagniappe/repl"
  autoload :Line,           "lagniappe/line"

  autoload :CommandFactory, "lagniappe/commands"
  autoload :BuiltInCommand, "lagniappe/commands"
  autoload :FileSystemCommand,  "lagniappe/commands"
  autoload :RubyCommand,    "lagniappe/commands"
  autoload :ShellCommand,   "lagniappe/commands"
  autoload :CommandError,   "lagniappe/commands"
  autoload :CommandUnknownError,   "lagniappe/commands"

  autoload :ExecutionContext,     "lagniappe/execution"
  autoload :CommandExecution,     "lagniappe/execution"
  autoload :FileSystemCommandExecution, "lagniappe/execution"
  autoload :RubyCommandExecution, "lagniappe/execution"
  autoload :ShellCommandExecution,"lagniappe/execution"

  module WorldAddons
    def self.syntax_ok?(file)
      `ruby -c #{file}`
      $?.exitstatus == 0
    end

    def self.load_from_files(files:[])
      files.map do |file|
        (puts "Cannot load world addon: #{file} does not exist" and next) unless File.exist?(file)
        (puts "Cannot load world addon: #{file} is not readable" and next) unless File.exist?(file)
        (puts "Cannot load world addon: #{file} is a directory file" and next) if File.directory?(file)

        # Module.new.tap { |m| m.module_eval IO.read(file) }
        IO.read(file)
      end
    end
  end


  def self.run_console
    addons = WorldAddons.load_from_files(files: [
      "#{ENV['HOME']}/.lagniapperc"
    ])
    console = Console.new(addons: addons)
    console.run
  end
end
