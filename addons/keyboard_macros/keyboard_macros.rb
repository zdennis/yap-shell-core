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
    @timeout_in_ms = 500
    @bindings_by_trigger_key = Hash.new { |h,k| h[k] = {} }
  end

  def configure(trigger_key=DEFAULT_TRIGGER_KEY, &blk)
    @trigger_key = trigger_key

    definitions = DefinitionMap.new
    blk.call definitions if blk

    world.unbind(trigger_key)
    world.bind(trigger_key) do
      begin
        @triggered_by_key = trigger_key
        @definitions = definitions
        world.editor.keyboard_input_processors.push(self)
        world.editor.input.wait_timeout_in_seconds = 0.1
      ensure
        queue_up_remove_input_processor
      end
    end
  end

  def queue_up_remove_input_processor
    event_args = {
      name: 'remove_input_processor',
      source: self,
      interval_in_ms: @timeout_in_ms
    }
    @event_id = world.editor.event_loop.once(event_args) do |event|
      @event_id = nil
      if world.editor.keyboard_input_processors.last == self
        world.editor.keyboard_input_processors.pop
        world.editor.input.restore_default_timeout
      end
    end
  end

  class DefinitionMap
    def initialize
      @storage = {}
    end

    def keys
      @storage.keys
    end

    def [](byte)
      @storage.each_pair do |key, value|
        case key
        when Regexp
          return value if key.match(byte.chr)
        else
          return value if key == byte
        end
      end
      nil
    end

    def []=(byte, val)
      @storage[byte] = val
    end

    def define(sequence, result, &blk)
      unless result.respond_to?(:call)
        string_result = result
        result = -> { string_result }
      end

      case sequence
      when String, Symbol
        recursively_define_sequence_for_bytes(
          self,
          sequence.to_s.bytes,
          result,
          &blk
        )
      when Regexp
        define_sequence_for_regex(self, sequence, result, &blk)
      else
        raise NotImplementedError, <<-EOT.gsub(/^\s*/, '')
          Don't know how to define macro for sequence#{sequence.inspect}
        EOT
      end
    end

    private

    def define_sequence_for_regex(definitions, regex, result, &blk)
      @storage[regex] = Definition.new(regex, result, &blk)
    end

    def recursively_define_sequence_for_bytes(definitions, bytes, result, &blk)
      byte, rest = bytes[0], bytes[1..-1]
      if rest.any?
        definition = Definition.new(byte, nil, &blk)
        definitions[byte] = definition
        recursively_define_sequence_for_bytes(
          definition.definitions,
          rest,
          result,
          &blk
        )
      else
        definitions[byte] = Definition.new(byte, result, &blk)
      end
    end
  end

  class Definition
    attr_reader :bytes, :definitions, :result, :sequence

    def initialize(sequence, result=nil, &blk)
      @sequence = sequence
      @bytes = sequence.to_s.bytes
      @result = result
      @definitions = DefinitionMap.new
      blk.call(@definitions) if blk
    end

    def first_byte
      @bytes.first
    end

    def process(captures: nil)
      @result.call(captures: captures) if @result
    end
  end

  #
  # InputProcessor Methods
  #

  def read_bytes(bytes)
    definition = nil
    definitions = @definitions
    bytes.each do |byte|
      definition = definitions[byte]
      break unless definition
      @definitions = definition.definitions
      result = definition.process
      if @definitions
        if @event_id
          @world.editor.event_loop.clear @event_id
          @event_id = queue_up_remove_input_processor
        end
        @world.editor.write result if result
      else
        @world.editor.write result if result
        break
      end
    end
  end
end
