module Yap::Shell::Execution
  class ShellCommandExecution < CommandExecution
    on_execute do |command:, n:, of:|
      func = command.to_proc
      command_result = func.call(args:command.args, stdin:@stdin, stdout:@stdout, stderr:@stderr)
      @stdout.close if @stdout != $stdout && !@stdout.closed?
      @stderr.close if @stderr != $stderr && !@stderr.closed?
    end
  end
end
