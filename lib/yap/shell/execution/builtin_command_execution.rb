module Yap::Shell::Execution
  require 'yap/shell/execution/result'

  class BuiltinCommandExecution < CommandExecution
    on_execute do |command:, n:, of:, wait:|
      Treefell['shell'].puts "builtin command executing: #{command}"
      status_code = command.execute(stdin:@stdin, stdout:@stdout, stderr:@stderr)
      if status_code == :resume
        Treefell['shell'].puts "builtin command execution resumed: #{command}"
        ResumeExecution.new(status_code:0, directory:Dir.pwd, n:n, of:of)
      else
        @stdout.close if @stdout != $stdout && !@stdout.closed?
        @stderr.close if @stderr != $stderr && !@stderr.closed?
        Result.new(status_code:status_code, directory:Dir.pwd, n:n, of:of).tap do |result|
          Treefell['shell'].puts "builtin command execution done with result=#{result.inspect}"
        end
      end
    end
  end
end
