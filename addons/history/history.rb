require 'forwardable'

class History
  def self.parent_module
    Module.nesting[1] # return the first parent of the current class (History)
  end

  def self.require_support_files(*files)
    lib_path = File.join File.dirname(__FILE__), "lib"
    files.each do |file|
      support_file = File.join lib_path, file
      support_file = "#{support_file}.rb" unless File.exists?(file)
      parent_module.module_eval IO.read(support_file), support_file, 1
    end
  end

  require_support_files 'history/group', 'history/item'

  def self.load_addon
    instance
  end

  def self.instance
    @history ||= History.new
  end

  def initialize
    @history = []
  end

  def initialize_world(world)
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
    @history.last.executing command:command, started_at:started_at
  end

  def executed(command:, stopped_at:)
    raise "Cannot complete execution of a command when no group has been started!" unless @history.last
    @history.last.executed command:command, stopped_at:stopped_at
  end

  def last_executed_item
    @history.reverse.each do |group|
      last_run = group.last_executed_item
      break last_run if last_run
    end
  end

  def start_group(started_at)
    @history.push Group.new(started_at:started_at)
  end

  def stop_group(stopped_at)
    @history.last.stopped_at(stopped_at)
  end

  private

  def history_file
    @history_file ||= File.expand_path('~') + '/.yap-history'
  end

  def load_history
    return unless File.exists?(history_file) && File.readable?(history_file)
    (YAML.load_file(history_file) || []).each do |item|
      ::Readline::HISTORY.push item
    end

    at_exit do
      File.write history_file, ::Readline::HISTORY.to_a.to_yaml
    end
  end
end


Yap::Shell::Execution::Context.on(:before_statements_execute) do |context|
  History.instance.start_group(Time.now)
end

Yap::Shell::Execution::Context.on(:after_statements_execute) do |context|
  History.instance.stop_group(Time.now)
  puts "After group: #{context.to_s}" if ENV["DEBUG"]
end

Yap::Shell::Execution::Context.on(:after_process_finished) do |context, *args|
  # puts "After process: #{context.to_s}, args: #{args.inspect}"
end

Yap::Shell::Execution::Context.on(:before_execute) do |context, command:|
  History.instance.executing command:command.str, started_at:Time.now
end

Yap::Shell::Execution::Context.on(:after_execute) do |context, command:, result:|
  History.instance.executed command:command.str, stopped_at:Time.now
end
