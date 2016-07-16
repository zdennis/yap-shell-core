module Yap
  module Cli
    module Options
      class Addon::Enable < Base
        def parse(args)
          @addon_name = args.shift unless args.first =~ /^-/
          unless @addon_name
            args.unshift '--help'
            STDERR.puts "Missing addon-name!"
            @exit_status = 1
            puts
          end
          option_parser.order!(args)
        end

        def command
          @command ||= load_command('addon/enable').new(@addon_name)
        end

        def exit_status
          @exit_status || 0
        end

        def help_message
          option_parser.to_s
        end

        private

        def option_parser
          OptionParser.new do |opts|
            opts.banner = <<-TEXT.gsub(/^\s*\|/, '')
              |Usage: #{opts.program_name} addon enable [addon-name] [options]
              |
              |#{Term::ANSIColor.cyan('yap addon enable')} can be used to enable yap addons.
              |
              |Addon enable options:
            TEXT

            opts.on('-h', '--help', 'Prints this help') do
              puts opts
              puts
              puts  <<-TEXT.gsub(/^\s*\|/, '')
                |Example: Disable an addon
                |
                |   #{opts.program_name} addon disable magical-key-bindings
                |
                |Example: Enable an addon
                |
                |   #{opts.program_name} addon enable magical-key-bindings
                |
              TEXT
              exit exit_status
            end
          end
        end
      end
    end
  end
end
