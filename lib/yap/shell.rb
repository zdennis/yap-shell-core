require 'readline'
require 'yaml'
require 'yap/shell/version'
require 'yap/shell/builtins'
require 'fcntl'

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
        @original_file_descriptor_flags = {
          stdin: $stdin.fcntl(Fcntl::F_GETFL, 0),
          stdout: $stdout.fcntl(Fcntl::F_GETFL, 0),
          stderr: $stderr.fcntl(Fcntl::F_GETFL, 0)
        }

        @stdin = $stdin
        @stdout = $stdout
        @stderr = $stderr

        @stdout.sync = true
        @stderr.sync = true

        @world = Yap::World.instance(addons:addons)
      end

      # Yields to the passed in block after restoring the file descriptor
      # flags that Yap started in. This ensures that any changes Yap has
      # made to run the shell don't interfere with child processes.
      def with_original_file_descriptor_flags(&block)
        current_file_descriptor_flags = {
          stdin: $stdin.fcntl(Fcntl::F_GETFL, 0),
          stdout: $stdout.fcntl(Fcntl::F_GETFL, 0),
          stderr: $stderr.fcntl(Fcntl::F_GETFL, 0)
        }

        $stdin.fcntl(Fcntl::F_SETFL, @original_file_descriptor_flags[:stdin])
        $stdout.fcntl(Fcntl::F_SETFL, @original_file_descriptor_flags[:stdout])
        $stderr.fcntl(Fcntl::F_SETFL, @original_file_descriptor_flags[:stderr])

        yield
      ensure
        $stdin.fcntl(Fcntl::F_SETFL, current_file_descriptor_flags[:stdin])
        $stdout.fcntl(Fcntl::F_SETFL, current_file_descriptor_flags[:stdout])
        $stderr.fcntl(Fcntl::F_SETFL, current_file_descriptor_flags[:stderr])
      end

      def repl
        context = Yap::Shell::Execution::Context.new(
          stdin:  @stdin,
          stdout: @stdout,
          stderr: @stderr
        )

        @world.repl.on_input do |input|
          evaluation = Yap::Shell::Evaluation.new(stdin:@stdin, stdout:@stdout, stderr:@stderr, world:@world)
          evaluation.evaluate(input) do |command, stdin, stdout, stderr, wait|
            context.clear_commands
            context.add_command_to_run command, stdin:stdin, stdout:stdout, stderr:stderr, wait:wait

            with_original_file_descriptor_flags do
              context.execute(world:@world)
            end
          end
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
