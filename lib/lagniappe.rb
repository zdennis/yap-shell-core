require "lagniappe/version"

module Lagniappe
  autoload :Console, "lagniappe/console"
  autoload :Shell,   "lagniappe/shell"
  autoload :World,   "lagniappe/world"

  def self.run_console
    Console.new.run
  end
end
