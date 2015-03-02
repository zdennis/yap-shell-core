module Yap::Shell::Execution
  class FileSystemCommandExecution < CommandExecution
    on_execute do |command:, n:, of:, resume_blk:nil|
      stdin, stdout, stderr, world = @stdin, @stdout, @stderr, @world
      result = nil
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
          stderr.close
        end
        # if stdin != $stdin && !stdin.closed? then stdin.close end

      rescue Interrupt
        Process.kill "SIGINT", pid

      rescue SuspendSignalError => ex
        Process.kill "SIGSTOP", pid

        # The Process started above with the PID +pid+ is a child process
        # so it has also received the suspend/SIGTSTP signal.
        suspended(command:command, n:n, of:of, pid: pid)

        result = SuspendExecution.new(status_code:nil, directory:Dir.pwd, n:n, of:of)
      end

      # if a signal killed or stopped the process (such as SIGINT or SIGTSTP) $? is nil.
      exitstatus = $? ? $?.exitstatus : nil
      result || Result.new(status_code:exitstatus, directory:Dir.pwd, n:n, of:of)
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
end
