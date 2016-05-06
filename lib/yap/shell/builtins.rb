module Yap::Shell
  require 'yap/shell/commands'

  module Builtins
    def self.builtin(name, &blk)
      Yap::Shell::BuiltinCommand.add(name, &blk)
    end

    def self.execute_builtin(name, world:, args:, stdin:, stdout:, stderr:)
      command = Yap::Shell::BuiltinCommand.new(world:world, str:name, args: args)
      command.execute(stdin:stdin, stdout:stdout, stderr:stderr)
    end

    Dir[File.dirname(__FILE__) + "/builtins/**/*.rb"].each do |f|
      require f
    end
  end
end
