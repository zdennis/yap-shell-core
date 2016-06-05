require 'uri'

module Yap::Shell::Execution
  class Context
    def self.on(event=nil, &blk)
      @on_callbacks ||= Hash.new{ |h,k| h[k] = [] }
      if event
        @on_callbacks[event.to_sym].push blk
      end
      @on_callbacks
    end

    def self.fire(event, context, *args)
      on[event.to_sym].each do |block|
        block.call(context, *args)
      end
    end

    def self.register(context, command_type:)
      raise "context cannot be nil" if context.nil?
      @registrations ||= {}
      @registrations[command_type] = context
      true
    end

    def self.execution_context_for(command)
      @registrations[command.type] || raise("No execution context found for given #{command.type} command: #{command.inspect}")
    end

    def initialize(stdin:, stdout:, stderr:)
      @stdin, @stdout, @stderr = stdin, stdout, stderr
      @command_queue = []
      @suspended_execution_contexts = []
    end

    def add_command_to_run(command, stdin:, stdout:, stderr:, wait:)
      @command_queue << [command, stdin, stdout, stderr, wait]
    end

    def clear_commands
      @command_queue.clear
    end

    def execute(world:)
      results = []
      @command_queue.each_with_index do |(command, stdin, stdout, stderr, wait), reversed_i|
        of = @command_queue.length
        i = reversed_i + 1
        stdin  = @stdin  if stdin  == :stdin
        stdout = @stdout if stdout == :stdout
        stderr = @stderr if stderr == :stderr

        execution_context_factory = self.class.execution_context_for(command)
        if execution_context_factory
          execution_context = execution_context_factory.new(
            stdin:  stdin,
            stdout: stdout,
            stderr: stderr,
            world:  world
          )

          @saved_tty_attrs = Termios.tcgetattr(STDIN) if STDIN.isatty

          Treefell['shell'].puts "firing :before_execute for #{command}"
          self.class.fire :before_execute, world, command: command

          begin
            result = execution_context.execute(command:command, n:i, of:of, wait:wait)
          rescue Exception => ex
            raise(ex) if ex.is_a?(SystemExit)

            Treefell['shell'].puts "rescued unexpected error=#{ex} with message=#{ex.message.inspect}"
            puts <<-ERROR.gsub(/^\s*\|/, '')
              |******************************
              |\e[31mWhoops! An unexpected error has occurred\e[0m
              |******************************
              |
              |The error was:
              |  #{ex.message}
              |
              |Backtrace:
              |#{ex.backtrace.join("\n")}
              |
              |Report this to yap-shell on github:
              |   https://github.com/zdennis/yap-shell/issues/new?title=#{URI.escape(ex.message)}
              |
            ERROR
          end

          Treefell['shell'].puts "firing :after_execute for #{command}"
          self.class.fire :after_execute, world, command: command, result: result

          results << process_execution_result(execution_context:execution_context, result:result)
          Termios.tcsetattr(STDIN, Termios::TCSANOW, @saved_tty_attrs) if STDIN.isatty
        end
      end

      clear_commands

      results.last
    end

    private

    def process_execution_result(execution_context:, result:)
      case result
      when SuspendExecution
        Treefell['shell'].puts "suspending execution context"
        @suspended_execution_contexts.push execution_context
        return result

      when ResumeExecution
        Treefell['shell'].puts "resuming suspended execution context"
        execution_context = @suspended_execution_contexts.pop
        if execution_context
          nresult = execution_context.resume
          Treefell['shell'].puts "resuming suspended execution context success"
          return process_execution_result execution_context: execution_context, result: nresult
        else
          Treefell['shell'].puts "error: cannot resume execution when there is nothing suspended"
          @stderr.puts "fg: No such job"
        end
      else
        return result
      end
    end
  end
end
