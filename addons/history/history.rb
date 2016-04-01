require 'forwardable'
require 'term/ansicolor'
require 'ostruct'

class History < Addon
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
        show_history(world.editor, stdout: stdout, redraw_prompt:false, ignore_history_item:ignore_history_item)
      else
        show_history(world.editor, stdout: stdout, redraw_prompt:false)
      end
    end
  end

  def show_history(editor, stdout:, redraw_prompt:true, ignore_history_item:nil, history_item_formatter:nil)
    stdout.puts @world.history
  end

  def executing(command:, started_at:)
    # raise "Cannot acknowledge execution beginning of a command when no group has been started!" unless history.last
  end

  def executed(command:, stopped_at:)
    # raise "Cannot complete execution of a command when no command has been started!" unless history.last
  end

  def save
    File.open(history_file, "a") do |file|
      # Don't write the YAML header because we're going to append to the
      # history file, not overwrite. YAML works fine without it.
      contents = @world.editor.history
        .to_a[@history_start_position..-1]
        .each_with_object([]) { |line, arr| arr << line unless line == arr.last  }
        .map { |str| str.respond_to?(:raw) ? str.raw : str }
        .to_yaml
        .gsub(/^---.*?^/m, '')
      file.write contents
    end
  end

  private

  def history_file
    @history_file ||= File.expand_path('~') + '/.yap-history'
  end

  def load_history
    @history_start_position = 0

    at_exit { save }

    return unless File.exists?(history_file) && File.readable?(history_file)

    history_elements = YAML.load_file(history_file) || []
    @history_start_position = history_elements.length
    @world.editor.history.replace(history_elements)
  end
end
