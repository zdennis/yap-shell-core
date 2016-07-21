module Yap
  module Addon
    class Reference
      attr_reader :name, :require_as, :path, :version

      def initialize(name:, require_as:, path:, version:, enabled: true)
        @name = name
        @require_as = require_as
        @path = path
        @enabled = enabled
        @version = version
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
