require 'readline'
require 'thread'
require 'yaml'

module Yap
  class Console
    def self.queue
      @queue ||= Queue.new
    end

    attr_reader :world

    def initialize(io_in:$stdin, prompt:"> ", addons:[])
      @io_in = io_in
      @world = World.new(prompt: prompt, addons:addons)
      @repl = Repl.new(world:world)
    end

    def history_file
      File.expand_path('~') + '/.yap-history'
    end

    def run
      at_exit do
        File.write history_file, ::Readline::HISTORY.to_a.to_yaml
      end

      STDOUT.sync = true

      context = ExecutionContext.new(
        stdin:  @stdin,
        stdout: @stdout,
        stderr: @stderr
      )

      @repl.loop_on_input do |command, stdin, stdout, stderr|
        puts "LOOP ON INPUT" if ENV["DEBUG"]
        context.clear_commands

        context.add_command_to_run command, stdin:stdin, stdout:stdout, stderr:stderr

        # Yap::ExecutionContext.fire :before_group_execute, self, commands:commands
        puts "context.before_group_execute" if ENV["DEBUG"]
        context.execute(world:@world)
        # Yap::ExecutionContext.fire :after_group_execute, self, commands:commands
        puts "context.after_group_execute" if ENV["DEBUG"]
      end
    end
  end

end
