module Lagniappe
  class ExecutionResult
    def self.parse(message)
      parts = message.scan /^(\d+)\/(\d+):(\d+):([^:]+)$/
      if parts.any?
        n, of, status_code, directory = parts.flatten
        ExecutionResult.new status_code:status_code.to_i, directory:directory, n:n.to_i, of:of.to_i
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
    def self.register(context, command_type:)
      raise "context cannot be nil" if context.nil?
      @registrations ||= {}
      @registrations[command_type] = context
      true
    end

    def self.execution_context_for(command)
      @registrations[command.type] || raise("No execution context found for given #{command.type} command: #{command.inspect}")
    end

    def initialize(shell:, stdin:, stdout:, stderr:)
      @shell = shell
      @stdin, @stdout, @stderr = stdin, stdout, stderr
      @command_queue = []
    end

    def add_command_to_run(command, stdin:, stdout:, stderr:)
      @command_queue << [command, stdin, stdout, stderr]
    end

    def execute(world:)
      @command_queue.each_with_index do |(command, stdin, stdout, stderr), i|
        stdin  = @stdin  if stdin  == :stdin
        stdout = @stdout if stdout == :stdout
        stderr = @stderr if stderr == :stderr

        fifos = [stdin,stdout,stderr].select{ |fifo| fifo && !File.exists?(fifo) }
        fifos.each{ |fifo| File.mkfifo(fifo) }

        execution_context = self.class.execution_context_for(command)
        if execution_context
          execution_context.new(
            shell:  @shell,
            stdin:  stdin,
            stdout: stdout,
            stderr: stderr,
            world:  world
          ).execute(command:command, n:i, of:@command_queue.length)
        else
        end
      end

      @command_queue.clear
    end
  end

  class CommandExecution
    attr_reader :shell, :stdin, :stdout, :stderr, :world

    def self.on_execute(&blk)
      if block_given?
        @on_execute_blk = blk
      else
        @on_execute_blk
      end
    end

    def initialize(shell:, stdin:, stdout:, stderr:,world:)
      @shell = shell
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
  end

  class BuiltinCommandExecution < CommandExecution
    on_execute do |command:, n:, of:|
      command.execute

      # Make up an exit code
      result = ExecutionResult.new(status_code:exit_code, directory:Dir.pwd, n:n, of:of)
      shell.stdin.puts result.to_shell_str
    end
  end

  class ShellCommandExecution < CommandExecution
    on_execute do |command:, n:, of:|
      cmd = "#{command.to_executable_str}"
      cmd << " < #{stdin}" if stdin
      cmd << " > #{stdout}" if stdout
      cmd << " 2> #{stderr}" if stderr

      result = ExecutionResult.new(status_code:"$?", directory:"`pwd`", n:n, of:of)
      cmd2exec = "( #{cmd} ; echo \"#{result.to_shell_str}\" ) &"
      puts "Executing: #{cmd2exec.inspect}" if ENV["DEBUG"]
      shell.puts cmd2exec
    end
  end

  class RubyCommandExecution < CommandExecution
    on_execute do |command:, n:, of:|
      shell, stdin, stdout, stderr, world = @shell, @stdin, @stdout, @stderr, @world
      t = Thread.new {
        exit_code = 0

        f = nil
        str = ""
        begin
          ruby_command = command.to_executable_str

          contents = if stdin.is_a?(String)
            f = File.open stdin
            f.read
          else
            ""
          end
          puts "READ: #{contents.length} bytes from #{stdin}" if ENV["DEBUG"]
          world.contents = contents

          method = ruby_command.scan(/^(\w+(?:[!?]|\s*=)?)/).flatten.first.gsub(/\s/, '')
          puts "method: #{method}" if ENV["DEBUG"]
          obj = if world.respond_to?(method)
            world
          elsif contents.respond_to?(method)
            contents
          else
            world
          end

          if ruby_command =~ /^[A-Z]|::/
            puts "Evaluating #{ruby_command} globally" if ENV["DEBUG"]
            str = eval ruby_command
          else
            ruby_command = "self.#{ruby_command}"
            puts "Evaluating #{ruby_command} on #{obj.inspect}" if ENV["DEBUG"]
            str = obj.instance_eval ruby_command
          end
        rescue Exception => ex
          str = <<-EOT.gsub(/^\s*\S/, '')
            |Failed processing ruby: #{ruby_command}
            |#{ex}
            |#{ex.backtrace.join("\n")}
          EOT
          exit_code = 1
        ensure
          f.close if f && !f.closed?
        end

        f2 = File.open stdout, "w"
        f2.sync = true

        # The next line  causes issues sometimes?
        # puts "WRITING #{str.length} bytes" if ENV["DEBUG"]
        f2.flush
        f2.write str

        f2.close

        # Make up an exit code
        result = ExecutionResult.new(status_code:exit_code, directory:Dir.pwd, n:n, of:of)
        shell.stdin.puts result.to_shell_str
      }
      t.abort_on_exception = true
      t
    end
  end


  ExecutionContext.register BuiltinCommandExecution, command_type: :BuiltinCommand
  ExecutionContext.register ShellCommandExecution,   command_type: :ShellCommand
  ExecutionContext.register RubyCommandExecution,    command_type: :RubyCommand

end
