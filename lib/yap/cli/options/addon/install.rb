module Yap
  module Cli
    module Options
      class Addon::Install < Base
        def parse(args)
          @addon_name = args.shift unless args.first =~ /^-/
          unless @addon_name
            args.unshift '--help'
            stderr.puts 'Missing addon-name!'
            @exit_status = 1
            puts
          end
          option_parser.order!(args)
        end

        def command
          @command ||= load_command('addon/install').new(@addon_name)
        end

        def help_message
          option_parser.to_s
        end

        private

        def option_parser
          OptionParser.new do |opts|
            opts.banner = <<-TEXT.gsub(/^\s*\|/, '')
              |Usage: #{opts.program_name} addon install <addon-name> [options]
              |
              |#{Colors.cyan('yap addon install')} can be used to install addons.
              |
              |Install options:
            TEXT

            opts.on('-h', '--help', 'Prints this help') do
              puts opts
              puts
              puts  <<-TEXT.gsub(/^\s*\|/, '')
                |Example: Install an addon
                |
                |   #{opts.program_name} addon install super-cool-thing
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
