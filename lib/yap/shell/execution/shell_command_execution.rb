module Yap::Shell::Execution
  class ShellCommandExecution < CommandExecution
    on_execute do |command:, n:, of:, wait:|
      possible_parameters = {
        command: command.str,
        args: command.args,
        stdin: @stdin,
        stdout: @stdout,
        stderr: @stderr,
        world: @world
      }

      func = command.to_proc
      params = func.parameters.reduce({}) do |h, (type, name)|
        h[name] = possible_parameters[name]
        h
      end

      command_result = func.call(**params)
      @stdout.close if @stdout != $stdout && !@stdout.closed?
      @stderr.close if @stderr != $stderr && !@stderr.closed?
    end
  end
end
