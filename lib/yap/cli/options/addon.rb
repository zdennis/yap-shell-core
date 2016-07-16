module Yap
  module Cli
    module Options
      class Addon < Base
        def parse(args)
          option_parser.order!(args)
        end

        def command
          @command
        end

        def help_message
          option_parser.to_s
        end

        private

        def set_command(command)
          @command = load_command('addon').new
        end

        def option_parser
          OptionParser.new do |opts|
            opts.banner = <<-TEXT.gsub(/^\s*\|/, '')
              |Usage: #{opts.program_name} addon [command] [addon-name] [options]
              |
              |#{Term::ANSIColor.cyan('yap addon')} can be used to control yap addons
              |
              |Generate commands:
              |
              |  #{Term::ANSIColor.yellow('enable')} - enables a yap addon
              |  #{Term::ANSIColor.yellow('disable')} - disables a yap addon
              |
              |Generate options:
            TEXT

            opts.on('-h', '--help', 'Prints this help') do
              puts opts
              puts
              puts  <<-TEXT.gsub(/^\s*\|/, '')
                |Example: disabling an addon
                |
                |   #{opts.program_name} addon disable foo-bar
                |
                |Example: enabling an addon
                |
                |   #{opts.program_name} addon enable foo-bar
                |
              TEXT
              exit 0
            end
          end
        end
      end
    end
  end
end
