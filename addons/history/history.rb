require 'forwardable'
require 'term/ansicolor'
require 'ostruct'

class History < Addon
  require 'history/group'
  require 'history/item'
  require 'history/buffer'
  require 'history/events'

  Color = Object.extend Term::ANSIColor

  class << self
    attr_accessor :history_item_formatter, :ignore_history_item
  end

  self.ignore_history_item = ->(item:) do
    item.command == "exit"
  end

  self.history_item_formatter = ->(item:, options:{}) do
    if item.duration
      sprintf(
        "%#{options[:max_position_width]}d %-s %s",
        item.position,
        item.command,
        Color.negative(Color.intense_black(item.duration))
      )
    else
      sprintf("%#{options[:max_position_width]}d %-s", item.position, item.command)
    end
  end

  def initialize_world(world)
    @world = world
    load_history

    world.editor.bind(:ctrl_h) { show_history(@world.editor) }

    world.func(:history) do |args:, stdin:, stdout:, stderr:|
      first_arg = args.first
      case first_arg
      when String
        if first_arg.start_with?("/")
          regex = first_arg.gsub(/(^\|\/$)/, '')
          ignore_history_item = ->(item:, options:{}) do
            item.command !~ /#{regex}/
          end
        else
          ignore_history_item = ->(item:, options:{}) do
            item.command !~ /#{first_arg}/
          end
        end
        show_history(world.editor, redraw_prompt:false, ignore_history_item:ignore_history_item)
      else
        show_history(world.editor, redraw_prompt:false)
      end
    end
  end

  def show_history(editor, redraw_prompt:true, ignore_history_item:nil, history_item_formatter:nil)
    ignore_history_item ||= self.class.ignore_history_item
    history_item_formatter ||= self.class.history_item_formatter

    pos = editor.line.position
    text = editor.line.text
    editor.puts

    history_items = history.map.with_index do |group, i|
      OpenStruct.new(
        command:group.command,
        duration:group.duration,
        position:(i+1).to_s
      )
    end

    term_width = editor.terminal_width
    max_position_width = history_items.map(&:position).map(&:length).max
    max_duration_width = history_items.map(&:duration).compact.map(&:length).max
    max_command_width = history_items.map(&:command).map(&:length).max

    history_items.each do |item|
      next if ignore_history_item.call(item:item)
      editor.puts history_item_formatter.call(item:item, options:{
        term_width: term_width,
        max_position_width: max_position_width,
        max_duration_width: max_duration_width,
        max_command_width: max_command_width
      })
    end

    editor.overwrite_line(text, pos) if redraw_prompt
  end

  def executing(command:, started_at:)
    raise "Cannot acknowledge execution beginning of a command when no group has been started!" unless history.last
    history.last.executing command:command, started_at:started_at
  end

  def executed(command:, stopped_at:)
    raise "Cannot complete execution of a command when no group has been started!" unless history.last
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
      File.open(history_file, "a") do |file|
        # Don't write the YAML header because we're going to append to the
        # history file, not overwrite. YAML works fine without it.
        file.write @world.editor.history.to_yaml(@history_start_position..-1).gsub(/^---\n/, '')
      end
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

    @history_start_position = history_elements.length
    @world.editor.history.replace(history_elements)
  end
end
