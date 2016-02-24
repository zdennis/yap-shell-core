Yap::Shell::Execution::Context.on(:before_statements_execute) do |world|
end

Yap::Shell::Execution::Context.on(:after_statements_execute) do |world|
end

Yap::Shell::Execution::Context.on(:before_execute) do |world, command:|
  # world[:history].executing command:command.str, started_at:Time.now
end

Yap::Shell::Execution::Context.on(:after_execute) do |world, command:, result:|
  # world[:history].executed command:command.str, stopped_at:Time.now
end
