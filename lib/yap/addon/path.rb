module Yap
  module Addon
    class Path
      def self.find_for_configuration(configuration)
        addons_config_hsh = {}
        if File.exists?(configuration.yap_addons_configuration_path)
          addons_config_hsh = YAML.load_file(configuration.yap_addons_configuration_path)
        end

        new(configuration.addon_paths.flatten, addons_config_hsh).
          references.sort_by(&:name)
      end

      attr_reader :references

      def initialize(paths, addons_config_hsh={})
        @paths = paths
        @addons_config_hsh = addons_config_hsh
      end

      def references
        @references ||= search_for_addons
      end

      private

      def search_for_addons
        @paths.each_with_object([]) do |path, results|
          Dir["#{path}/*"].map do |directory|
            next unless File.directory?(directory)

            if File.basename(directory) =~ /(yap-shell-addon-(.*))-\d+\.\d+\.\d+/
              require_as, name = $1, $2

              addonrb_path = directory + "/lib/" + require_as + ".rb"
              export_as = ExportAs.find_in_file(addonrb_path)
              name = export_as if export_as
              name = name.to_sym

              enabled = !@addons_config_hsh.fetch(
                name, { disabled: false }
              )[:disabled]

              results << Yap::Addon::Reference.new(
                name: name,
                require_as: require_as,
                path: File.expand_path(directory),
                enabled: enabled
              )
            end
          end
        end
      end
    end
  end
end
