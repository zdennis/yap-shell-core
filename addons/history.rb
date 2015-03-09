module Yap
  module WorldAddons
    class History
      def self.load
        @history ||= History.new
      end

      def initialize_world(world)
        load_history
      end

      private

      def history_file
        @history_file ||= File.expand_path('~') + '/.yap-history'
      end

      def load_history
        return unless File.exists?(history_file) && File.readable?(history_file)
        (YAML.load_file(history_file) || []).each do |item|
          ::Readline::HISTORY.push item
        end

        at_exit do
          File.write history_file, ::Readline::HISTORY.to_a.to_yaml
        end
      end
    end
  end
end
