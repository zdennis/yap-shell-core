module Lagniappe
  class Line
    attr_reader :body, :heredoc

    def initialize(raw_line, heredoc:heredoc)
      @raw_line = raw_line
      @heredoc = heredoc
      @chain = parse_commands_into Array.new
      @chain.last.heredoc = heredoc
    end

    def commands
      @chain
    end

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
