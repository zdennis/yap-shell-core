require 'yap/support/file_utils_helper'

module Yap
  module Cli
    module Commands
      class Base
        include ::Yap::Support::FileUtilsHelper
      end
    end
  end
end
