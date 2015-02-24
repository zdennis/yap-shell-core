module Yap::Shell::Execution
  class BuiltinCommandExecution < CommandExecution
    on_execute do |command:, n:, of:|
      command_output = command.execute
      @stdout.write command_output
      @stdout.close if @stdout != $stdout && !@stdout.closed?
      @stderr.close if @stderr != $stderr && !@stderr.closed?
    end
  end
end
