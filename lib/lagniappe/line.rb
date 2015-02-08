module Lagniappe
  class Line
    attr_reader :body, :heredoc

    def initialize(statements, heredoc:heredoc)
      @statements = statements
      @heredoc = heredoc
      @chain = parse_statements_into_commands
      @chain.last.heredoc = heredoc
    end

    def commands
      @chain
    end

    private

    def parse_statements_into_commands
      @statements.map do |statement|
        command = CommandFactory.build_command_for(statement.command)
        command.args = statement.args
        command
      end
    end

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
