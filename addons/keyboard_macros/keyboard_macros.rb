class KeyboardMacros < Addon
  DEFAULT_TRIGGER_KEY = :ctrl_g
  DEFAULT_CANCEL_KEY = " "
  DEFAULT_TIMEOUT_IN_MS = 500

  def self.load_addon
    @instance ||= new
  end

  attr_reader :world
  attr_accessor :timeout_in_ms
  attr_accessor :cancel_key, :trigger_key
  attr_accessor :cancel_on_unknown_sequences

  def initialize_world(world)
    @world = world
    @configurations = []
    @stack = []
    @timeout_in_ms = DEFAULT_TIMEOUT_IN_MS
    @cancel_key = DEFAULT_CANCEL_KEY
    @trigger_key = DEFAULT_TRIGGER_KEY
    @cancel_on_unknown_sequences = false
  end

  def configure(cancel_key: nil, trigger_key: nil, &blk)
    cancel_key ||= @cancel_key
    trigger_key ||= @trigger_key

    cancel_blk = lambda do
      world.editor.event_loop.clear @event_id
      cancel_processing
      nil
    end

    configuration = Configuration.new(
      keymap: world.editor.terminal.keys,
      trigger_key: trigger_key,
      cancellation: Cancellation.new(cancel_key: cancel_key, &cancel_blk)
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
        cancel_processing if cancel_on_unknown_sequences
        break
      end
      configuration = definition.configuration
      if configuration
        configuration.start.call if configuration.start
        @stack << configuration
      end
      result = definition.process
      @stack.pop if definition.fragment?
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

  class Cancellation
    attr_reader :cancel_key

    def initialize(cancel_key: , &blk)
      @cancel_key = cancel_key
      @blk = blk
    end

    def call
      @blk.call
    end
  end

  class Configuration
    attr_reader :cancellation, :trigger_key, :keymap

    def initialize(cancellation: nil, keymap: {}, trigger_key: nil)
      @cancellation = cancellation
      @keymap = keymap
      @trigger_key = trigger_key
      @storage = {}
      @on_start_blk = nil
      @on_stop_blk = nil

      if @cancellation
        define @cancellation.cancel_key, -> { @cancellation.call }
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

    def fragment(sequence, result)
      define(sequence, result).tap do |definition|
        definition.fragment!
      end
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
          @keymap.fetch(sequence){
            fail "Cannot bind unknown sequence #{sequence.inspect}"
          },
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
        configuration: Configuration.new(
          cancellation: @cancellation,
          keymap: @keymap
        ),
        sequence: regex,
        result: result,
        &blk
      )
    end

    def recursively_define_sequence_for_bytes(configuration, bytes, result, &blk)
      byte, rest = bytes[0], bytes[1..-1]
      if rest.any?
        definition = Definition.new(
          configuration: Configuration.new(
            cancellation: @cancellation,
            keymap: @keymap
          ),
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
      @fragment = false
      @configuration = configuration
      @sequence = sequence
      @result = result
      blk.call(@configuration) if blk
    end

    def fragment?
      @fragment
    end

    def fragment!
      @fragment = true
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
