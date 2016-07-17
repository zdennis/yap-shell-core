module Yap
  module Cli
    module Options
      class Generate < Base
        def parse(args)
          if args.empty?
            args.unshift '--help'
            stderr.puts "generate must be called with a component type!"
            @exit_status = 1
            puts
          end

          option_parser.order!(args)
        end

        def command
          @command ||= load_command('generate').new
        end

        def exit_status
          @exit_status || 0
        end

        private

        def option_parser
          OptionParser.new do |opts|
            opts.banner = <<-TEXT.gsub(/^\s*\|/, '')
              |Usage: #{opts.program_name} generate [component-type] [options]
              |
              |#{Colors.cyan('yap generate')} can be used to generate yap components, like an addon.
              |
              |Generate commands:
              |
              |  #{Colors.yellow('addon')} - generates a yap addon skeleton
              |
              |Generate options:
            TEXT

            opts.on('-h', '--help', 'Prints this help') do
              puts opts
              puts
              puts  <<-TEXT.gsub(/^\s*\|/, '')
                |Example: Generating an addon
                |
                |   #{opts.program_name} generate addon magical-key-bindings
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
