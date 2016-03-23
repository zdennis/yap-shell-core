class KeyboardMacros < Addon
  DEFAULT_TRIGGER_KEY = :ctrl_g
  DEFAULT_CANCELLATION_TRIGGER_KEY = :tab

  def self.load_addon
    @instance ||= new
  end

  attr_reader :world
  attr_accessor :trigger_key

  def initialize_world(world)
    @world = world
    @configurations = []
    @stack = []
    @triggered_by_key = nil
    @timeout_in_ms = nil
  end

  class Cancellation
    attr_reader :trigger_key

    def initialize(trigger_key=DEFAULT_CANCELLATION_TRIGGER_KEY, &blk)
      @trigger_key = trigger_key
      @blk = blk
    end

    def call
      @blk.call
    end
  end

  def configure(trigger_key=DEFAULT_TRIGGER_KEY, &blk)
    cancel_blk = lambda do
      world.editor.event_loop.clear @event_id
      cancel_processing
      nil
    end

    configuration = Configuration.new(
      keymap: world.editor.terminal.keys,
      trigger_key: trigger_key,
      cancellation: Cancellation.new(&cancel_blk)
    )

    blk.call configuration if blk

    world.unbind(trigger_key)
    world.bind(trigger_key) do
      begin
        @stack << configuration
        configuration.start.call if configuration.start
        world.editor.keyboard_input_processors.push(self)
        world.editor.input.wait_timeout_in_seconds = 0.1
      ensure
        queue_up_remove_input_processor(&configuration.stop)
      end
    end

    @configurations << configuration
  end

  #
  # InputProcessor Methods
  #

  def read_bytes(bytes)
    configuration = @stack.last
    bytes.each do |byte|
      definition = configuration[byte]
      if !definition
        cancel_processing
        break
      end
      configuration = definition.configuration
      if configuration
        configuration.start.call if configuration.start
        @stack << configuration
      end
      result = definition.process
      if @event_id
        world.editor.event_loop.clear @event_id
        @event_id = queue_up_remove_input_processor
      end
      world.editor.write result if result.is_a?(String)
    end
  end

  private

  def queue_up_remove_input_processor(&blk)
    return unless @timeout_in_ms

    event_args = {
      name: 'remove_input_processor',
      source: self,
      interval_in_ms: @timeout_in_ms,
    }
    @event_id = world.editor.event_loop.once(event_args) do
      cancel_processing
    end
  end

  def cancel_processing
    @event_id = nil
    @stack.reverse.each do |configuration|
      configuration.stop.call if configuration.stop
    end
    @stack.clear
    if world.editor.keyboard_input_processors.last == self
      world.editor.keyboard_input_processors.pop
      world.editor.input.restore_default_timeout
    end
  end

  class Configuration
    attr_reader :cancellation, :trigger_key, :keymap

    def initialize(keymap: {}, trigger_key: nil, cancellation: nil)
      @keymap = keymap
      @trigger_key = trigger_key
      @cancellation = cancellation
      @storage = {}
      @on_start_blk = nil
      @on_stop_blk = nil

      if @cancellation
        define @cancellation.trigger_key, -> { @cancellation.call }
      end
    end

    def start(&blk)
      @on_start_blk = blk if blk
      @on_start_blk
    end

    def stop(&blk)
      @on_stop_blk = blk if blk
      @on_stop_blk
    end

    def define(sequence, result, &blk)
      unless result.respond_to?(:call)
        string_result = result
        result = -> { string_result }
      end

      case sequence
      when String
        recursively_define_sequence_for_bytes(
          self,
          sequence.bytes,
          result,
          &blk
        )
      when Symbol
        recursively_define_sequence_for_bytes(
          self,
          @keymap[sequence],
          result,
          &blk
        )
      when Regexp
        define_sequence_for_regex(sequence, result, &blk)
      else
        raise NotImplementedError, <<-EOT.gsub(/^\s*/, '')
          Don't know how to define macro for sequence: #{sequence.inspect}
        EOT
      end
    end

    def [](byte)
      @storage.values.detect { |definition| definition.matches?(byte) }
    end

    def []=(key, definition)
      @storage[key] = definition
    end

    private

    def define_sequence_for_regex(regex, result, &blk)
      @storage[regex] = Definition.new(
        configuration: Configuration.new(keymap: @keymap, cancellation: @cancellation),
        sequence: regex,
        result: result,
        &blk
      )
    end

    # macro.define 'abc', 'echo abc'
    # 1) recur: self, 'abc', 'echo abc'
    #       self['a'] = Definition.new('a', nil)
    #       r
    # 2) recur:
    def recursively_define_sequence_for_bytes(configuration, bytes, result, &blk)
      byte, rest = bytes[0], bytes[1..-1]
      if rest.any?
        definition = Definition.new(
          configuration: Configuration.new(keymap: @keymap, cancellation: @cancellation),
          sequence: byte,
          result: nil,
          &blk
        )
        configuration[byte] = definition
        recursively_define_sequence_for_bytes(
          definition.configuration,
          rest,
          result,
          &blk
        )
      else
        configuration[byte] = Definition.new(
          configuration: Configuration.new(keymap: @keymap),
          sequence: byte,
          result: result,
          &blk
        )
      end
    end
  end

  class Definition
    attr_reader :bytes, :configuration, :result, :sequence

    def initialize(configuration: nil, sequence:, result: nil, &blk)
      @configuration = configuration
      @sequence = sequence
      @result = result
      blk.call(@configuration) if blk
    end

    def matches?(byte)
      if @sequence.is_a?(Regexp)
        @match_data = @sequence.match(byte.chr)
      else
        @sequence == byte
      end
    end

    def process
      if @result
        if @match_data
          if @match_data.captures.empty?
            @result.call(@match_data[0])
          else
            @result.call(*@match_data.captures)
          end
        else
          @result.call
        end
      end
    end
  end

end
