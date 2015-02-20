module Yap::Shell::Execution
  class CommandExecution
    attr_reader :stdin, :stdout, :stderr, :world

    def self.on_execute(&blk)
      if block_given?
        @on_execute_blk = blk
      else
        @on_execute_blk
      end
    end

    def initialize(stdin:, stdout:, stderr:,world:)
      @stdin, @stdout, @stderr = stdin, stdout, stderr
      @world = world
    end

    def execute(command:, n:, of:)
      if self.class.on_execute
        self.instance_exec(command:command, n:n, of:of, &self.class.on_execute)
      else
        raise NotImplementedError, "on_execute block hasn't been implemented!"
      end
    end

    def suspended?
      @suspended
    end
  end
end
