module Yap
  class Shell
    module Execution
      autoload :Context,                    "yap/shell/execution/context"

      autoload :CommandExecution,           "yap/shell/execution/command_execution"
      autoload :BuiltinCommandExecution,    "yap/shell/execution/builtin_command_execution"
      autoload :FileSystemCommandExecution, "yap/shell/execution/file_system_command_execution"
      autoload :RubyCommandExecution,       "yap/shell/execution/ruby_command_execution"
      autoload :ShellCommandExecution,      "yap/shell/execution/shell_command_execution"

      autoload :Result,                     "yap/shell/execution/result"

      Context.register BuiltinCommandExecution,    command_type: :BuiltinCommand
      Context.register FileSystemCommandExecution, command_type: :FileSystemCommand
      Context.register ShellCommandExecution,      command_type: :ShellCommand
      Context.register RubyCommandExecution,       command_type: :RubyCommand
    end
  end
end
