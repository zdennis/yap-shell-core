require 'yap/shell/commands'

module Yap::Shell
  module Builtins
    def self.builtin(name, &blk)
      Yap::Shell::BuiltinCommand.add(name, &blk)
    end

    Dir[File.dirname(__FILE__) + "/builtins/**/*.rb"].each do |f|
      require f
    end
  end
end
