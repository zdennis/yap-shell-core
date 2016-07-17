require 'fileutils'

module Yap
  module Support
    class FileUtils
      def basename(*args)
        ::File.basename(*args)
      end

      def dirname(*args)
        ::File.dirname(*args)
      end

      def join(*paths)
        ::File.join(*paths)
      end

      def mkdir_p(*args)
        ::FileUtils.mkdir_p(*args)
      end

      def read(*args)
        ::File.read(*args)
      end

      def write(*args)
        ::File.write(*args)
      end
    end
  end
end
