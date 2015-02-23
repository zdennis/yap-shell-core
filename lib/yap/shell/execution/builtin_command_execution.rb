module Yap::Shell::Execution
  class BuiltinCommandExecution < CommandExecution
    on_execute do |command:, n:, of:|
      command_output = command.execute
      @stdout.write command_output
    end
  end
end
