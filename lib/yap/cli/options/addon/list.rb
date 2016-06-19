module Yap
  module Cli
    class Options::Addon::List
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
        @command ||= load_command('addon/list').new
      end

      private

      def option_parser
        OptionParser.new do |opts|
          opts.on('-h') do
            puts opts
            exit 0
          end          
          opts.on('--enabled') do
            command.filter = :enabled
          end
          opts.on('--disabled') do
            command.filter = :disabled
          end
        end
      end
    end
  end
end
