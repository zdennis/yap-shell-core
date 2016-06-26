module Yap
  module Addon
    class Reference
      attr_reader :name, :require_as, :path

      def initialize(name:, require_as:, path:, disabled:)
        @name = name
        @require_as = require_as
        @path = path
        @disabled = disabled
      end

      def disabled? ; @disabled ; end
      def enabled? ; !disabled? ; end
    end
  end
end
