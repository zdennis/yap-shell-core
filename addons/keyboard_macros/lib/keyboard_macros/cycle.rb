class KeyboardMacros
  class Cycle
    def initialize(cycle_proc:, on_cycle_proc: nil)
      @cycle_proc = cycle_proc
      @on_cycle_proc = on_cycle_proc
      @previous_result = nil
      reset
    end

    def next
      @index = -1 if @index >= cycle_values.length - 1
      on_cycle cycle_values[@index += 1]
    end

    def previous
      @index = cycle_values.length if @index < 0
      on_cycle cycle_values[@index -= 1]
    end

    def reset
      @index = -1
      @previous_result = nil
      @cycle_values = nil
    end

    private

    def cycle_values
      @cycle_values ||= @cycle_proc.call
    end

    def on_cycle(new_value)
      @on_cycle_proc.call(@previous_result, new_value) if @on_cycle_proc
      @previous_result = new_value
      new_value
    end
  end
end
