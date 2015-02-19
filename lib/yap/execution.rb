module Yap
  class ExecutionResult
    def self.parse(message)
      parts = message.scan /^(\d+)\/(\d+):(\d*):([^:]+)$/
      if parts.any?
        # if status_code is nil it may be due to a process exiting due to
        # a signal error.
        n, of, status_code, directory = parts.flatten
        status_code = status_code.to_i if status_code
        ExecutionResult.new status_code:status_code, directory:directory, n:n.to_i, of:of.to_i
      end
    end

    attr_reader :status_code, :directory, :n, :of

    def initialize(status_code:, directory:, n:, of:)
      @status_code = status_code
      @directory = directory
      @n = n
      @of = of
    end

    # Format: <command number>/<total commands to run>:<status code>
    def to_shell_str
      "#{@of - @n}/#{@of}:#{@status_code}:#{@directory}"
    end
  end

  class ExecutionContext
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

  class CommandExecution
    attr_reader :stdin, :stdout, :stderr, :world

    def self.on_execute(&blk)
      if block_given?
        @on_execute_blk = blk
      else
        @on_execute_blk
      end
    end

    def initialize(stdin:, stdout:, stderr:,world:)
      @stdin, @stdout, @stderr = stdin, stdout, stderr
      @world = world
    end

    def execute(command:, n:, of:)
      if self.class.on_execute
        self.instance_exec(command:command, n:n, of:of, &self.class.on_execute)
      else
        raise NotImplementedError, "on_execute block hasn't been implemented!"
      end
    end

    def suspended?
      @suspended
    end
  end

  class BuiltinCommandExecution < CommandExecution
    on_execute do |command:, n:, of:|
      command_result = command.execute
      result = ExecutionResult.new(status_code:0, directory:Dir.pwd, n:n, of:of)
      command_result
    end
  end

  class FileSystemCommandExecution < CommandExecution
    on_execute do |command:, n:, of:, resume_blk:nil|
      stdin, stdout, stderr, world = @stdin, @stdout, @stderr, @world
      begin
        if resume_blk
          pid = resume_blk.call
        else
          r,w = nil, nil
          if command.heredoc
            r,w = IO.pipe
            stdin = r
          end

          pid = fork do
            # Start a new process gruop as the session leader. Now we are
            # responsible for sending signals that would have otherwise
            # been propagated to the process, e.g. SIGINT, SIGSTOP, SIGCONT, etc.
            stdin  = File.open(stdin, "rb") if stdin.is_a?(String)
            stdout = File.open(stdout, "wb") if stdout.is_a?(String)
            stderr = File.open(stderr, "wb") if stderr.is_a?(String)

            stdout = stderr if stdout == :stderr
            stderr = stdout if stderr == :stdout

            $stdin.reopen stdin
            $stdout.reopen stdout
            $stderr.reopen stderr
            Process.setsid

            Kernel.exec command.to_executable_str
          end
          if command.heredoc
            w.write command.heredoc
            w.close
          end
        end

        # This prevents the shell from processing sigint and lets the child
        # process handle it. Necessary for interactive shells that do not
        # abort on Ctrl-C such as irb.
        Signal.trap("SIGINT") do
          Process.kill("SIGINT", pid)
        end

        Process.waitpid(pid) unless of > 1
        Signal.trap("SIGINT", "DEFAULT")

        # If we're not printing to the terminal than close in/out/err. This
        # is so the next command in the pipeline can complete and don't hang waiting for
        # stdin after the command that's writing to its stdin has completed.
        if stdout != $stdout && stdout.is_a?(IO) && !stdout.closed? then
          stdout.close
        end
        if stderr != $stderr && stderr.is_a?(IO) && !stderr.closed? then
          puts "COSE2"
          stderr.close
        end
        # if stdin != $stdin && !stdin.closed? then stdin.close end

      rescue Interrupt
        Process.kill "SIGINT", pid

      rescue SuspendSignalError
        Process.kill "SIGSTOP", pid
        # The Process started above with the PID +pid+ is a child process
        # so it has also received the suspend/SIGTSTP signal.
        suspended(command:command, n:n, of:of, pid: pid)
      end

      # if a signal killed or stopped the process (such as SIGINT or SIGTSTP) $? is nil.
      exitstatus = $? ? $?.exitstatus : nil
      result = ExecutionResult.new(status_code:exitstatus, directory:Dir.pwd, n:n, of:of)
      result
    end

    def resume
      args = @suspended
      @suspended = nil

      puts "Resuming: #{args[:pid]}" if ENV["DEBUG"]
      resume_blk = lambda do
        Process.kill "SIGCONT", args[:pid]
        args[:pid]
      end

      self.instance_exec command:args[:command], n:args[:n], of:args[:of], resume_blk:resume_blk, &self.class.on_execute
    end

    def suspended(command:, n:, of:, pid:)
      puts "Suspending: #{pid}" if ENV["DEBUG"]
      @suspended = {
        command: command,
        n: n,
        of: of,
        pid: pid
      }
    end
  end

  class ShellCommandExecution < CommandExecution
    on_execute do |command:, n:, of:|
      func = command.to_proc
      command_result = func.call(args:command.args, stdin:@stdin, stdout:@stdout, stderr:@stderr)
      @stdout.close if @stdout != $stdout && !@stdout.closed?
      @stderr.close if @stderr != $stderr && !@stderr.closed?
    end
  end

  class RubyCommandExecution < CommandExecution
    on_execute do |command:, n:, of:|
      stdin, stdout, stderr, world = @stdin, @stdout, @stderr, @world
      t = Thread.new {
        exit_code = 0
        first_command = n == 1

        f = nil
        result = nil
        begin
          ruby_command = command.to_executable_str

          contents = if stdin.is_a?(String)
            puts "READ: stdin as a String: #{stdin.inspect}" if ENV["DEBUG"]
            f = File.open stdin
            f.read
          elsif stdin != $stdin
            puts "READ: stdin is not $stdin: #{stdin.inspect}" if ENV["DEBUG"]
            stdin.read
          else
            puts "READ: contents is: #{contents.inspect}" if ENV["DEBUG"]
          end

          puts "READ: #{contents.length} bytes from #{stdin}" if ENV["DEBUG"] && contents
          world.contents = contents

          method = ruby_command.scan(/^(\w+(?:[!?]|\s*=)?)/).flatten.first.gsub(/\s/, '')
          puts "method: #{method}" if ENV["DEBUG"]

          obj = if first_command
            world
          elsif contents.respond_to?(method)
            contents
          else
            world
          end

          if ruby_command =~ /^[A-Z0-9]|::/
            puts "Evaluating #{ruby_command.inspect} globally" if ENV["DEBUG"]
            result = eval ruby_command
          else
            ruby_command = "self.#{ruby_command}"
            puts "Evaluating #{ruby_command.inspect} on #{obj.inspect}" if ENV["DEBUG"]
            result = obj.instance_eval ruby_command
          end
        rescue Exception => ex
          result = <<-EOT.gsub(/^\s*\S/, '')
            |Failed processing ruby: #{ruby_command}
            |#{ex}
            |#{ex.backtrace.join("\n")}
          EOT
          exit_code = 1
        ensure
          f.close if f && !f.closed?
        end

        # The next line  causes issues sometimes?
        # puts "WRITING #{result.length} bytes" if ENV["DEBUG"]
        result = result.to_s
        result << "\n" unless result.end_with?("\n")

        stdout.write result
        stdout.flush
        stderr.flush

        stdout.close if stdout != $stdout && !stdout.closed?
        stderr.close if stderr != $stderr && !stderr.closed?

        # Pass current execution to give any other threads a chance
        # to be scheduled before we send back our status code. This could
        # probably use a more elaborate signal or message passing scheme,
        # but that's for another day.
        Thread.pass

        # Make up an exit code
        exec_result = ExecutionResult.new(status_code:exit_code, directory:Dir.pwd, n:n, of:of)
        exec_result
      }
      t.abort_on_exception = true
      t
    end
  end


  ExecutionContext.register BuiltinCommandExecution, command_type: :BuiltinCommand
  ExecutionContext.register FileSystemCommandExecution,  command_type: :FileSystemCommand
  ExecutionContext.register ShellCommandExecution,   command_type: :ShellCommand
  ExecutionContext.register RubyCommandExecution,    command_type: :RubyCommand

end
