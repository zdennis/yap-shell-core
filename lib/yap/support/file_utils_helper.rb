require 'yap/support/file_utils'
require 'yap/support/file_loader'

module Yap
  module Support
    module FileUtilsHelper
      def file_utils
        FileUtils.new
      end

      def file_loader
        FileLoader
      end
    end
  end
end
