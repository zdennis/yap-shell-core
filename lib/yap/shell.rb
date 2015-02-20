require 'readline'
require 'yaml'

module Yap
  class Shell
    autoload :Evaluation, "yap/shell/evaluation"
    autoload :Repl, "yap/shell/repl"

    def initialize(addons:)
      @stdin = $stdin
      @stdout = $stdout
      @stderr = $stderr

      @stdout.sync = true
      @stderr.sync = true

      @addons = addons
    end

    def repl
      @world = Yap::World.new(addons:@addons)
      context = ExecutionContext.new(
        stdin:  @stdin,
        stdout: @stdout,
        stderr: @stderr
      )

      @repl = Yap::Shell::Repl.new(world:@world)
      @repl.loop_on_input do |input|
        evaluation = Yap::Shell::Evaluation.new(stdin:@stdin, stdout:@stdout, stderr:@stderr)
        evaluation.evaluate(input) do |command, stdin, stdout, stderr|
          context.clear_commands
          context.add_command_to_run command, stdin:stdin, stdout:stdout, stderr:stderr
          context.execute(world:@world)
        end
      end
    end

    private

    def history_file
      File.expand_path('~') + '/.yap-history'
    end

    def load_history
      return unless File.exists?(history_file) && File.readable?(history_file)
      (YAML.load_file(history_file) || []).each do |item|
        ::Readline::HISTORY.push item
      end

      at_exit do
        File.write history_file, ::Readline::HISTORY.to_a.to_yaml
      end
    end

  end
end
