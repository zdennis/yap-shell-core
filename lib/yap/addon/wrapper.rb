module Yap
  module Addon
    class Wrapper
      def initialize(addon)
        @addon = addon
        @enabled = true
      end

      def disable!
        @enabled = false
      end

      def disabled?
        !@enabled
      end

      def enabled?
        @enabled
      end

      def method_missing(name, *args, &blk)
        if enabled?
          @addon.send name, *args, &blk
        else
          Treefell['addon'].puts "Not sending #{name} to #{@addon} because it is disabled"
        end
      end
    end
  end
end
