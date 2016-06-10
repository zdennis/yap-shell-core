require 'readline'
require 'yaml'
require 'fcntl'

module Yap
  module Shell
    require 'yap/shell/version'
    require 'yap/shell/builtins'

    autoload :Aliases, "yap/shell/aliases"

    autoload :CommandFactory, "yap/shell/commands"
    autoload :CommandError,  "yap/shell/commands"
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

        addons_str = "\n  - " + addons.map(&:class).map(&:name).join("\n  - ")
        Treefell['shell'].puts "Constructing world instance with addons: #{addons_str}"
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
          Treefell['shell'].puts "repl received input: #{input.inspect}"
          evaluation = Yap::Shell::Evaluation.new(stdin:@stdin, stdout:@stdout, stderr:@stderr, world:@world)
          evaluation.evaluate(input) do |command, stdin, stdout, stderr, wait|
            Treefell['shell'].puts <<-DEBUG.gsub(/^\s*\|/, '')
              |adding #{command} to run in context of:
              |  stdin: #{stdin.inspect}
              |  stdout: #{stdout.inspect}
              |  stderr: #{stderr.inspect}
              |  wait for child process to complete? #{wait.inspect}
            DEBUG
            context.clear_commands
            context.add_command_to_run command, stdin:stdin, stdout:stdout, stderr:stderr, wait:wait

            with_original_file_descriptor_flags do
              context.execute(world:@world)
            end
          end
        end

        begin
          Treefell['shell'].puts "enter interactive mode"
          @world.interactive!
        # rescue Errno::EIO => ex
        #   # This happens when yap is no longer the foreground process
        #   # but it tries to receive input/output from the tty. I believe it
        #   # is a race condition when launching a child process.
        rescue Interrupt
          Treefell['shell'].puts "^C"
          @world.editor.puts "^C"
          retry
        rescue Exception => ex
          if !ex.is_a?(SystemExit)
            if $stdout.isatty
              binding.pry
            else
              raise ex
            end
          end
        end
      end
    end
  end
end
