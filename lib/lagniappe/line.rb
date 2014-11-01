module Lagniappe
  class Line
    include Enumerable

    attr_reader :body

    def initialize(raw_line)
      @raw_line = raw_line
      @chain = parse_commands_into Array.new
    end

    def commands
      @chain
    end

    def each(&block)
      @chain.each(&block)
    end
    alias_method :each_command, :each

    private

    def parse_commands_into(chain)
      scope = []
      words = []
      str = ''

      @raw_line.each_char.with_index do |ch, i|
        popped = false
        if scope.last == ch
          scope.pop
          popped = true
        end

        if (scope.empty? && ch == "|") || (i == @raw_line.length - 1)
          str << ch unless ch == "|"
          chain << CommandFactory.build_command_for(str.strip)
          str = ''
        else
          if !popped
            if %w(' ").include?(ch)
              scope << ch
            elsif ch == "{"
              scope << "}"
            elsif ch == "["
              scope << "]"
            end
          end
          str << ch
        end
      end

      chain
    end
  end
end
