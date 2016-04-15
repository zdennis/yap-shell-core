class KeyboardMacros < Addon
  require 'keyboard_macros/cycle'

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
      cancellation: Cancellation.new(cancel_key: cancel_key, &cancel_blk),
      editor: world.editor,
    )

    blk.call configuration if blk

    world.unbind(trigger_key)
    world.bind(trigger_key) do
      begin
        @previous_result = nil
        @stack << OpenStruct.new(configuration: configuration)
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
    if @stack.last
      current_definition = @stack.last
      configuration = current_definition.configuration
    end

    bytes.each_with_index do |byte, i|
      definition = configuration[byte]
      if !definition
        cancel_processing if cancel_on_unknown_sequences
        break
      end

      configuration = definition.configuration
      configuration.start.call if configuration.start
      @stack << definition

      result = definition.process

      if result =~ /\n$/
        world.editor.write result.chomp, add_to_line_history: false
        world.editor.event_loop.clear @event_id if @event_id
        cancel_processing
        world.editor.newline # add_to_history
        world.editor.process_line
        break
      end

      if i == bytes.length - 1
        while @stack.last && @stack.last.fragment?
          @stack.pop
        end
      end

      if @event_id
        world.editor.event_loop.clear @event_id
        @event_id = queue_up_remove_input_processor
      end

      if result.is_a?(String)
        world.editor.write result, add_to_line_history: false
        @previous_result = result
      end
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
    @stack.reverse.each do |definition|
      definition.configuration.stop.call if definition.configuration.stop
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

    def initialize(cancellation: nil, editor:, keymap: {}, trigger_key: nil)
      @cancellation = cancellation
      @editor = editor
      @keymap = keymap
      @trigger_key = trigger_key
      @storage = {}
      @on_start_blk = nil
      @on_stop_blk = nil
      @cycles = {}

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

    def cycle(name, &cycle_thru_blk)
      if block_given?
        cycle = KeyboardMacros::Cycle.new(
          cycle_proc: cycle_thru_blk,
          on_cycle_proc: -> (old_value, new_value) {
            @editor.delete_n_characters(old_value.to_s.length)
          }
        )
        @cycles[name] = cycle
      else
        @cycles.fetch(name)
      end
    end

    def fragment(sequence, result)
      define(sequence, result, fragment: true)
    end

    def define(sequence, result=nil, fragment: false, &blk)
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
          fragment: fragment,
          &blk
        )
      when Symbol
        recursively_define_sequence_for_bytes(
          self,
          @keymap.fetch(sequence){
            fail "Cannot bind unknown sequence #{sequence.inspect}"
          },
          result,
          fragment: fragment,
          &blk
        )
      when Regexp
        define_sequence_for_regex(sequence, result, fragment: fragment, &blk)
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

    def inspect
      str = @storage.map{ |k,v| "#{k}=#{v.inspect}" }.join("\n  ")
      num_items = @storage.reduce(0) { |s, arr| s + arr.length }
      "<Configuration num_items=#{num_items} stored_keys=#{str}>"
    end

    private

    def define_sequence_for_regex(regex, result, fragment: false, &blk)
      @storage[regex] = Definition.new(
        configuration: Configuration.new(
          cancellation: @cancellation,
          keymap: @keymap,
          editor: @editor
        ),
        fragment: fragment,
        sequence: regex,
        result: result,
        &blk
      )
    end

    def recursively_define_sequence_for_bytes(configuration, bytes, result, fragment: false, &blk)
      byte, rest = bytes[0], bytes[1..-1]
      if rest.any?
        definition = if configuration[byte]
          configuration[byte]
        else
          Definition.new(
            configuration: Configuration.new(
              cancellation: @cancellation,
              keymap: @keymap,
              editor: @editor
            ),
            fragment: fragment,
            sequence: byte,
            result: nil
          )
        end
        blk.call(definition.configuration) if blk
        configuration[byte] = definition
        recursively_define_sequence_for_bytes(
          definition.configuration,
          rest,
          result,
          fragment: fragment,
          &blk
        )
      else
        definition = Definition.new(
          configuration: Configuration.new(
            keymap: @keymap,
            editor: @editor
          ),
          fragment: fragment,
          sequence: byte,
          result: result
        )
        configuration[byte] = definition
        blk.call(definition.configuration) if blk
        definition
      end
    end
  end

  class Definition
    attr_reader :configuration, :result, :sequence

    def initialize(configuration: nil, fragment: false, sequence:, result: nil)
      @fragment = fragment
      @configuration = configuration
      @sequence = sequence
      @result = result
    end

    def inspect
      "<Definition fragment=#{@fragment.inspect} sequence=#{@sequence.inspect} result=#{@result.inspect} configuration=#{@configuration.inspect}>"
    end

    def fragment?
      @fragment
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
