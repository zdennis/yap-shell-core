require 'yap/cli/console/printer'

module Yap
  module Cli
    module Commands
      class Addon::List < Base
        def filter=(filter_kind)
          @filter = filter_kind
        end

        def print_list(addon_refs, with_state: true)
          data = addon_refs.group_by(&:name).map do |name, refs|
            sorted_refs = refs.sort_by(&:version)
            most_recent_ref = sorted_refs.last
            enabled_or_disabled = most_recent_ref.enabled? ? Colors.green('enabled') : Colors.intense_black('disabled')
            [most_recent_ref.name.to_s, enabled_or_disabled, "(#{refs.reverse.map(&:version).join(', ')})"]
          end
          Console::Printer.new(data).print_table
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
            print_list addon_refs.select(&:enabled?)
          elsif @filter == :disabled
            print_list addon_refs.select(&:disabled?)
          else
            print_list addon_refs
          end
        end
      end
    end
  end
end
