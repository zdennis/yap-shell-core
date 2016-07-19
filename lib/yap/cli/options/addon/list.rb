module Yap
  module Cli
    module Options
      class Addon::List < Base
        def parse(args)
          option_parser.order!(args)
        end

        def command
          @command ||= load_command('addon/list').new
        end

        def help_message
          option_parser.to_s
        end

        private

        def option_parser
          OptionParser.new do |opts|
            opts.banner = <<-TEXT.gsub(/^\s*\|/, '')
              |Usage: #{opts.program_name} addon list [options]
              |
              |#{Colors.cyan('yap addon list')} can be used to list yap addons.
              |
              |Addon list options:
            TEXT

            opts.on('-h', '--help', 'Prints this help') do
              puts opts
              puts
              puts  <<-TEXT.gsub(/^\s*\|/, '')
                |Example: Listing all addons
                |
                |   #{opts.program_name} addon list
                |
                |Example: Listing disabled addons only
                |
                |   #{opts.program_name} addon list --disabled
                |
                |Example: Listing enabled addons only
                |
                |   #{opts.program_name} addon list --enabled
                |
              TEXT
              exit 0
            end
            opts.on('--enabled', 'Lists yap addons that are enabled') do
              command.filter = :enabled
            end
            opts.on('--disabled', 'Lists yap addons that are disabled') do
              command.filter = :disabled
            end
          end
        end
      end
    end
  end
end
