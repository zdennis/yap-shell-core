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

  autoload :ExecutionContext,     "lagniappe/execution"
  autoload :CommandExecution,     "lagniappe/execution"
  autoload :FileSystemCommandExecution, "lagniappe/execution"
  autoload :RubyCommandExecution, "lagniappe/execution"
  autoload :ShellCommandExecution,"lagniappe/execution"

  def self.run_console
    Console.new.run
  end
end
