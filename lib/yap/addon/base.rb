module Yap
  module Addon
    class Base
      def self.load_addon
        @instance ||= new
      end

      def self.addon_name
        @addon_name ||= begin
          addon_name = self.name.split(/::/)
            .last.scan(/[A-Z][^A-Z]+/)
            .map(&:downcase).reject{ |f| f == "addon" }
            .join("_")
            .to_sym
          addon_name.length == 0 ? self.name : addon_name
        end
      end

      def self.export_as(name=nil)
        if name
          @export_as = name.to_sym
        end
        @export_as
      end

      def self.logger
        calling_method = caller[1][/`.*'/][1..-2]
        Treefell["addon:#{export_as}"]["#{name}##{calling_method}"]
      end

      def addon_name
        @addon_name ||= self.class.addon_name
      end

      def logger
        self.class.logger
      end

      def export_as
        self.class.export_as
      end

      def initialize(enabled: true)
        @yap_enabled = enabled
      end

      def yap_enabled?
        @yap_enabled
      end
    end
  end
end
