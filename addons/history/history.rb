require 'forwardable'

class History < Addon
  require 'history/group'
  require 'history/item'
  require 'history/buffer'

  def initialize_world(world)
    @world = world
    load_history

    world.func(:howmuch) do |args:, stdin:, stdout:, stderr:|
      case args.first
      when "time"
        if history_item=self.last_executed_item
          stdout.puts history_item.total_time_s
        else
          stdout.puts "Can't report on something you haven't done."
        end
      else
        stdout.puts "How much what?"
      end
    end
  end

  def executing(command:, started_at:)
    raise "Cannot acknowledge execution beginning of a command when no group has been started!" unless @history.last
    history.last.executing command:command, started_at:started_at
  end

  def executed(command:, stopped_at:)
    raise "Cannot complete execution of a command when no group has been started!" unless @history.last
    history.last.executed command:command, stopped_at:stopped_at
  end

  def last_executed_item
    history.reverse.each do |group|
      last_run = group.last_executed_item
      break last_run if last_run
    end
  end

  def start_group(started_at)
    last_command = history[-1]
    history[-1] = Group.new(started_at:started_at, command:last_command)
  end

  def stop_group(stopped_at)
    history.last.stopped_at(stopped_at)
  end

  private

  def history
    @history
  end

  def history_file
    @history_file ||= File.expand_path('~') + '/.yap-history'
  end

  def load_history
    @world.editor.history = @history = History::Buffer.new(Float::INFINITY)

    at_exit do
      File.write history_file, @world.editor.history.to_yaml
    end

    return unless File.exists?(history_file) && File.readable?(history_file)

    history_elements = YAML.load_file(history_file) || []
    history_elements.map! do |element|
      case element
      when String
        Group.from_string(element)
      when Hash
        Group.from_hash(element)
      else
        raise "Don't know how to load history from #{element.inspect}"
      end
    end

    @world.editor.history.replace(history_elements)
  end
end

Yap::Shell::Execution::Context.on(:before_statements_execute) do |world|
  world[:history].start_group(Time.now)
end

Yap::Shell::Execution::Context.on(:after_statements_execute) do |world|
  world[:history].stop_group(Time.now)
end

Yap::Shell::Execution::Context.on(:after_process_finished) do |world, *args|
  # puts "After process: #{world.to_s}, args: #{args.inspect}"
end

Yap::Shell::Execution::Context.on(:before_execute) do |world, command:|
  world[:history].executing command:command.str, started_at:Time.now
end

Yap::Shell::Execution::Context.on(:after_execute) do |world, command:, result:|
  world[:history].executed command:command.str, stopped_at:Time.now
end
