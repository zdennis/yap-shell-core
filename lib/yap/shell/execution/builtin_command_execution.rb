module Yap::Shell::Execution
  class BuiltinCommandExecution < CommandExecution
    on_execute do |command:, n:, of:|
      status_code = command.execute(stdin:@stdin, stdout:@stdout, stderr:@stderr)
      if status_code == :resume
        ResumeExecution.new(status_code:0, directory:Dir.pwd, n:n, of:of)
      else
        @stdout.close if @stdout != $stdout && !@stdout.closed?
        @stderr.close if @stderr != $stderr && !@stderr.closed?
        Result.new(status_code:status_code, directory:Dir.pwd, n:n, of:of)
      end
    end
  end
end
