module Yap
  module Cli
    module Commands
      class Addon::Enable
        def initialize(addon_name)
          @addon_name = addon_name
        end

        def process
          configuration = Yap.configuration
          addon_refs = Yap::World::AddonPaths.find_for_configuration(configuration)
          addon_config_hsh = {}
          found_addon_ref = nil
          addon_refs.each do |addon_ref|
            is_disabled = addon_ref.disabled?
            if addon_ref.name.to_s == @addon_name.to_s
              is_disabled = false
              found_addon_ref = addon_ref
            end
            addon_config_hsh[addon_ref.name] = { disabled: is_disabled }
          end

          if found_addon_ref
            destination = configuration.yap_addons_configuration_path.to_s
            FileUtils.mkdir_p File.dirname(destination)
            File.write destination, addon_config_hsh.to_yaml
            puts "Addon #{found_addon_ref.name} has been enabled"
          else
            puts "Could not find addon with name #{@addon_name}"
          end
        end
      end
    end
  end
end
