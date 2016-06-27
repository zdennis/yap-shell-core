module Yap
  module Addon
    class Reference
      attr_reader :name, :require_as, :path

      def initialize(name:, require_as:, path:, enabled: true)
        @name = name
        @require_as = require_as
        @path = path
        @enabled = enabled
      end

      def disabled?
        !@enabled
      end

      def enabled?
        @enabled
      end
    end
  end
end
