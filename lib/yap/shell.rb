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

        @world = Yap::World.instance(addons:addons)
      end

      def repl
        context = Yap::Shell::Execution::Context.new(
          stdin:  @stdin,
          stdout: @stdout,
          stderr: @stderr
        )

        last_result = nil

        @world.repl.on_input do |input|
          evaluation = Yap::Shell::Evaluation.new(stdin:@stdin, stdout:@stdout, stderr:@stderr, world:@world, last_result:last_result)
          evaluation.evaluate(input) do |command, stdin, stdout, stderr, wait|
            context.clear_commands
            context.add_command_to_run command, stdin:stdin, stdout:stdout, stderr:stderr, wait:wait
            last_result = context.execute(world:@world)
          end
          @world.editor.reset_line
        end

        begin
          @world.interactive!
        # rescue Errno::EIO => ex
        #   # This happens when yap is no longer the foreground process
        #   # but it tries to receive input/output from the tty. I believe it
        #   # is a race condition when launching a child process.
        rescue Interrupt
          puts "^C"
          retry
        rescue Exception => ex
          require 'pry'
          binding.pry unless ex.is_a?(SystemExit)
        end
      end
    end
  end
end
