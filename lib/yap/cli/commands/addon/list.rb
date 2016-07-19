module Yap
  module Cli
    module Commands
      class Addon::List < Base
        def filter=(filter_kind)
          @filter = filter_kind
        end

        def process
          configuration = Yap.configuration

          addon_refs = ::Yap::Addon::Path.
            find_for_configuration(configuration)
          if addon_refs.empty?
            puts <<-MSG.gsub(/^\s*\|/, '')
              |No addons found searching paths:
              |  - #{configuration.addon_paths.join("\n  -")}
            MSG
          elsif @filter == :enabled
            addon_refs.select(&:enabled?).each do |addon_ref|
              puts "#{addon_ref.name}"
            end
          elsif @filter == :disabled
            addon_refs.select(&:disabled?).each do |addon_ref|
              puts "#{addon_ref.name}"
            end
          else
            addon_refs.each do |addon_ref|
              enabled_or_disabled = addon_ref.enabled? ? 'enabled' : 'disabled'
              puts "#{addon_ref.name} (#{enabled_or_disabled})"
            end
          end
        end
      end
    end
  end
end
