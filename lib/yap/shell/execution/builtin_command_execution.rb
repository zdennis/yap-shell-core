module Yap
  class Shell
    module Execution

      class BuiltinCommandExecution < CommandExecution
        on_execute do |command:, n:, of:|
          command_result = command.execute
        end
      end

    end
  end
end
