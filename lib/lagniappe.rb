require "lagniappe/version"

module Lagniappe
  autoload :Console, "lagniappe/console"
  autoload :Shell,   "lagniappe/shell"
  autoload :World,   "lagniappe/world"

  autoload :Repl,           "lagniappe/repl"
  autoload :Line,           "lagniappe/line"
  autoload :CommandChain,   "lagniappe/commands"
  autoload :CommandFactory, "lagniappe/commands"
  autoload :RubyCommand,    "lagniappe/commands"
  autoload :ShellCommand,   "lagniappe/commands"

  def self.run_console
    Console.new.run
  end
end
