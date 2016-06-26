module Yap
  module Cli
    class Options::Generate::Addon
      include OptionsLoader

      attr_reader :command, :options

      def initialize(options:)
        @options = options
        @exit_status = 0
      end

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
        @command ||= load_command('generate/addon').new(@addon_name)
      end

      private

      def option_parser
        OptionParser.new do |opts|
          opts.banner = <<-TEXT.gsub(/^\s*\|/, '')
            |Usage: #{opts.program_name} generate addon [addon-name] [options]
            |
            |#{Term::ANSIColor.cyan('yap addon')} can be used to generate a yap addon skeleton provided an addon name.
            |
            |Generate addon options:
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
            exit @exit_status
          end
        end
      end
    end
  end
end
