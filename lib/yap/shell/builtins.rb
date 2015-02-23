require 'yap/shell/commands'

module Yap::Shell
  module Builtins
    def self.builtin(name, &blk)
      Yap::Shell::BuiltinCommand.add(name, &blk)
    end

    def self.execute_builtin(name, *args)
      builtin = Yap::Shell::BuiltinCommand.builtins.fetch(name){ raise("Builtin #{name} not found") }
      builtin.call *args
    end

    Dir[File.dirname(__FILE__) + "/builtins/**/*.rb"].each do |f|
      require f
    end
  end
end
