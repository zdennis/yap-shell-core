require 'yap/shell/execution/result'
require 'termios'

module Yap::Shell::Execution
  class FileSystemCommandExecution < CommandExecution
    on_execute do |command:, n:, of:, resume_blk:nil|
      stdin, stdout, stderr, world = @stdin, @stdout, @stderr, @world
      result = nil
      if resume_blk
        pid = resume_blk.call
      else
        r,w = nil, nil
        if command.heredoc
          r,w = IO.pipe
          stdin = r
        end

        pid = fork do
          # reset signals in case any were ignored
          Signal.trap("SIGINT",  "DEFAULT")
          Signal.trap("SIGQUIT", "DEFAULT")
          Signal.trap("SIGTSTP", "DEFAULT")
          Signal.trap("SIGTTIN", "DEFAULT")
          Signal.trap("SIGTTOU", "DEFAULT")

          # Set the process group of the forked to child to that of the
          Process.setpgrp

          # Start a new process group as the session leader. Now we are
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

          Kernel.exec command.to_executable_str
        end

        # Put the child process into a process group of its own
        Process.setpgid pid, pid

        if command.heredoc
          w.write command.heredoc
          w.close
        end
      end

      # Set terminal's process group to that of the child process
      Termios.tcsetpgrp STDIN, pid
      pid, status = Process.wait2(-1, Process::WUNTRACED) unless of > 1
      puts "Process (#{pid}) stopped: #{status.inspect}" if ENV["DEBUG"]

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


      # if the pid that just stopped was the process group owner then
      # give it back to the us so we can become the foreground process
      # in the terminal
      if pid == Termios.tcgetpgrp(STDIN)
        Process.setpgid Process.pid, Process.pid
        Termios.tcsetpgrp STDIN, Process.pid
      end

      # if the reason we stopped is from being suspended
      if status.stopsig == Signal.list["TSTP"]
        puts "Process (#{pid}) suspended: #{status.stopsig}" if ENV["DEBUG"]
        suspended(command:command, n:n, of:of, pid: pid)
        result = Yap::Shell::Execution::SuspendExecution.new(status_code:nil, directory:Dir.pwd, n:n, of:of)
      else
        puts "Process (#{pid}) not suspended? #{status.stopsig}" if ENV["DEBUG"]
        # if a signal killed or stopped the process (such as SIGINT or SIGTSTP) $? is nil.
        exitstatus = $? ? $?.exitstatus : nil
        result = Yap::Shell::Execution::Result.new(status_code:exitstatus, directory:Dir.pwd, n:n, of:of)
      end
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
