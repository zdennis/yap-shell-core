module Yap::Shell::Execution
  class ShellCommandExecution < CommandExecution
    on_execute do |command:, n:, of:, wait:|
      Treefell['shell'].puts "shell command execution: #{command}"

      possible_parameters = {
        command: command.str,
        args: command.args,
        stdin: @stdin,
        stdout: @stdout,
        stderr: @stderr,
        world: @world,
        line: command.line
      }

      func = command.to_proc
      params = func.parameters.reduce({}) do |h, (type, name)|
        h[name] = possible_parameters[name]
        h
      end

      Treefell['shell'].puts "shell command executing with params: #{params.inspect}"
      command_result = func.call(**params)
      @stdout.close if @stdout != $stdout && !@stdout.closed?
      @stderr.close if @stderr != $stderr && !@stderr.closed?
    end
  end
end
