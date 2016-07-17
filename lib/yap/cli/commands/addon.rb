module Yap
  module Cli
    module Commands
      class Addon < Base
        def initialize(addon_name)
          @addon_name = addon_name
        end

        def process
        end
      end
    end
  end
end
