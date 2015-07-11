require 'readline'
require 'yaml'
require 'yap/shell/version'
require 'yap/shell/builtins'

module Yap
  module Shell
    autoload :Aliases, "yap/shell/aliases"

    autoload :CommandFactory, "yap/shell/commands"
    autoload :CommandError,  "yap/shell/commands"
    autoload :CommandUnknownError,  "yap/shell/commands"
    autoload :BuiltinCommand,  "yap/shell/commands"
    autoload :FileSystemCommand,  "yap/shell/commands"
    autoload :RubyCommand,  "yap/shell/commands"
    autoload :ShellCommand,  "yap/shell/commands"

    autoload :Execution,  "yap/shell/execution"

    autoload :Evaluation, "yap/shell/evaluation"
    autoload :Repl, "yap/shell/repl"

    class Impl
      def initialize(addons:)
        @stdin = $stdin
        @stdout = $stdout
        @stderr = $stderr

        @stdout.sync = true
        @stderr.sync = true

        @world = Yap::World.new(addons:addons)
      end

      def repl
        context = Yap::Shell::Execution::Context.new(
          stdin:  @stdin,
          stdout: @stdout,
          stderr: @stderr
        )

        last_result = nil
        @world.repl.loop_on_input do |input|
          evaluation = Yap::Shell::Evaluation.new(stdin:@stdin, stdout:@stdout, stderr:@stderr, world:@world, last_result:last_result)
          evaluation.evaluate(input) do |command, stdin, stdout, stderr|
            context.clear_commands
            context.add_command_to_run command, stdin:stdin, stdout:stdout, stderr:stderr
            last_result = context.execute(world:@world)
          end
        end
      end
    end
  end
end
