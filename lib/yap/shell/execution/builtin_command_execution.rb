require 'yap/shell/execution/result'

module Yap::Shell::Execution
  class BuiltinCommandExecution < CommandExecution
    on_execute do |command:, n:, of:|
      command_output = command.execute
      if command_output == :resume
        ResumeExecution.new(status_code:0, directory:Dir.pwd, n:n, of:of)
      else
        @stdout.write command_output
        @stdout.close if @stdout != $stdout && !@stdout.closed?
        @stderr.close if @stderr != $stderr && !@stderr.closed?
        Result.new(status_code:0, directory:Dir.pwd, n:n, of:of)
      end
    end
  end
end
