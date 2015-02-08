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
        command = CommandFactory.build_command_for(statement)
        command.args = statement.args if statement.respond_to?(:args)
        command
      end
    end
  end
end
