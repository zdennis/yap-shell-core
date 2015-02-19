require "yap/version"

module Yap
  autoload :Shell, "yap/shell"
  autoload :World, "yap/world"

  autoload :CommandFactory, "yap/commands"
  autoload :BuiltInCommand, "yap/commands"
  autoload :FileSystemCommand,  "yap/commands"
  autoload :RubyCommand,    "yap/commands"
  autoload :ShellCommand,   "yap/commands"
  autoload :CommandError,   "yap/commands"
  autoload :CommandUnknownError,   "yap/commands"

  autoload :ExecutionContext,     "yap/execution"
  autoload :CommandExecution,     "yap/execution"
  autoload :FileSystemCommandExecution, "yap/execution"
  autoload :RubyCommandExecution, "yap/execution"
  autoload :ShellCommandExecution,"yap/execution"

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


  def self.run_shell
    addons = WorldAddons.load_from_files(files: [
      "#{ENV['HOME']}/.yaprc"
    ])
    Shell.new(addons: addons).repl
  end
end
