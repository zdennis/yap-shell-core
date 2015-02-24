module Yap::Shell::Execution
  class Result
    attr_reader :status_code, :directory, :n, :of

    def initialize(status_code:, directory:, n:, of:)
      @status_code = status_code
      @directory = directory
      @n = n
      @of = of
    end
  end

  class SuspendExecution < Result
  end

  class ResumeExecution < Result
  end
end
