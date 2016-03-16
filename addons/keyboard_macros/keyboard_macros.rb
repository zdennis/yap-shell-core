class KeyboardMacros < Addon
  DEFAULT_TRIGGER_KEY = :ctrl_g

  def self.load_addon
    @instance ||= new
  end

  attr_reader :world
  attr_accessor :trigger_key

  def initialize_world(world)
    @world = world
    @trigger_key = DEFAULT_TRIGGER_KEY
    @triggered_by_key = nil
    @timeout_in_ms = 250
    @bindings_by_trigger_key = Hash.new { |h,k| h[k] = {}}
  end

  def configure(trigger_key: DEFAULT_TRIGGER_KEY, &blk)
    @trigger_key = trigger_key

    yield self

    world.unbind(trigger_key)
    world.bind(trigger_key) do
      begin
        @triggered_by_key = trigger_key
        world.editor.keyboard_input_processors.push(self)
        world.editor.input.wait_timeout_in_seconds = 0.2
      ensure
        world.editor.event_loop.once name: 'remove_input_processor', source: self, interval_in_ms: @timeout_in_ms do
          if world.editor.keyboard_input_processors.last == self
            world.editor.keyboard_input_processors.pop
            world.editor.input.restore_default_timeout
          end
        end
      end
    end
  end

  def define(key, result)
    unless result.respond_to?(:call)
      string_result = result
      result = -> { string_result }
    end
    @bindings_by_trigger_key[@trigger_key][key.to_s.bytes] = result
  end

  #
  # InputProcessor Methods
  #

  def read_bytes(bytes)
    if @bindings_by_trigger_key[@triggered_by_key].has_key?(bytes)
      result = @bindings_by_trigger_key[@triggered_by_key][bytes].call
      if result[-1] == "\n"
        @world.editor.write result
        @world.editor.event_loop.once name: 'process_line', source: self, interval_in_ms: 0 do
          @world.editor.process_line
        end
      else
        @world.editor.write result
      end
    else
      # no-op, nothing registered
    end
  end
end
