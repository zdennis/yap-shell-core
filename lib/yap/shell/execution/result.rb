module Yap
  class Shell
    module Execution

      class Result
        attr_reader :status_code, :directory, :n, :of

        def initialize(status_code:, directory:, n:, of:)
          @status_code = status_code
          @directory = directory
          @n = n
          @of = of
        end
      end

    end
  end
end
