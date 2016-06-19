module Yap
  module Cli
    class Options::Addon::Disable
      include OptionsLoader

      attr_reader :command, :options

      def initialize(options:)
        @options = options
      end

      def parse(args)
        @addon_name = args.shift unless args.first =~ /^-/
        option_parser.order!(args)
      end

      def command
        @command ||= load_command('addon/disable').new(@addon_name)
      end

      private

      def option_parser
        OptionParser.new do |opts|
          opts.on('-h') do
            puts opts
            exit 0
          end
        end
      end
    end
  end
end
