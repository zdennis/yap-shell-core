require "yap/shell/execution/context"
require "yap/shell/execution/command_execution"
require "yap/shell/execution/builtin_command_execution"
require "yap/shell/execution/file_system_command_execution"
require "yap/shell/execution/ruby_command_execution"
require "yap/shell/execution/shell_command_execution"
require "yap/shell/execution/result"

module Yap::Shell
  module Execution
    Context.register BuiltinCommandExecution,    command_type: :BuiltinCommand
    Context.register FileSystemCommandExecution, command_type: :FileSystemCommand
    Context.register ShellCommandExecution,      command_type: :ShellCommand
    Context.register RubyCommandExecution,       command_type: :RubyCommand
  end
end
