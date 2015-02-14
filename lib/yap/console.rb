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

    def preload_shells(n=1)
      @shells ||= n.times.map{ Shell.new }
      return unless File.exists?(history_file)
      (YAML.load_file(history_file) || []).each do |item|
        ::Readline::HISTORY.push item
      end
    end

    def history_file
      File.expand_path('~') + '/.yap-history'
    end

    def run
      preload_shells

      at_exit do
        File.write history_file, ::Readline::HISTORY.to_a.to_yaml

        Dir["fifo-test-*"].each do |f|
          (FileUtils.rm f rescue nil)
        end
      end

      STDOUT.sync = true

      shell = @shells.first
      shell.open_pty

      t = Thread.new do
        status_code = nil
        begin
          sleep 0.1

          loop do
            $stdout.print shell.pty_master.read_nonblock(8192)
            $stdout.flush
          end
        rescue IO::EAGAINWaitReadable
          if output = (shell.stdout.read_nonblock(8192) rescue nil)
            output.split("\n").each do |line|
              puts "ENQ: #{line.inspect}" if ENV["DEBUG"]
              Console.queue.enq line
            end
            status_code = should_exit = nil
            retry
          else
            retry
          end
        end
      end
      t.abort_on_exception = true

      context = ExecutionContext.new(
        shell:  shell,
        stdin:  nil,
        stdout: shell.pty_slave.path,
        stderr: shell.pty_slave.path
      )

      @repl.loop_on_input do |command, stdin, stdout, stderr|
        puts "LOOP ON INPUT" if ENV["DEBUG"]
        context.clear_commands

        # pipeline = CommandPipeline.new(commands:commands.reverse)
        # pipeline.each.with_index do |(command, stdin, stdout, stderr), i|
        #   context.add_command_to_run command, stdin:stdin, stdout:stdout, stderr:stderr
        # end
        context.add_command_to_run command, stdin:stdin, stdout:stdout, stderr:stderr

        # Yap::ExecutionContext.fire :before_group_execute, self, commands:commands
        puts "context.before_group_execute" if ENV["DEBUG"]
        context.execute(world:@world)
        # Yap::ExecutionContext.fire :after_group_execute, self, commands:commands
        puts "context.after_group_execute" if ENV["DEBUG"]

        messages = []
        return_value = nil
        loop do
          puts "loop" if ENV["DEBUG"]
          begin
            message = Console.queue.deq
            messages << message
            puts "DEQ'd #{message.inspect}" if ENV["DEBUG"]
            result = ExecutionResult.parse message
            return_value = result
            if result
              Yap::ExecutionContext.fire :after_process_finished, self
              Dir.chdir result.directory
              shell.puts "cd #{result.directory.shellescape}"
              break if messages.length == result.of
            end
          rescue Interrupt
            shell.interrupt!
          end
        end

        return_value
      end
    end
  end

end
