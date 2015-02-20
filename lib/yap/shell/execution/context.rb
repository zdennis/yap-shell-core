module Yap
  class Shell
    module Execution

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

        def add_command_to_run(command, stdin:, stdout:, stderr:)
          @command_queue << [command, stdin, stdout, stderr]
        end

        def clear_commands
          @command_queue.clear
        end

        def execute(world:)
          @command_queue.each_with_index do |(command, stdin, stdout, stderr), reversed_i|
            of = @command_queue.length
            i = of - reversed_i
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

              self.class.fire :before_execute, execution_context, command: command
              result = execution_context.execute(command:command, n:i, of:of)
              self.class.fire :after_execute, execution_context, command: command, result: result

              case result
              when :resume
                execution_context = @suspended_execution_contexts.pop
                if execution_context
                  execution_context.resume
                else
                  puts "fg: No such job"
                  next
                end
              end

              if execution_context.suspended?
                @suspended_execution_contexts.push execution_context
              end
            end

          end

          clear_commands
        end
      end

    end
  end
end
