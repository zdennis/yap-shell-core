module Yap
  module Cli
    class Options::Generate
      include OptionsLoader

      attr_reader :command, :options

      def initialize(options:)
        @options = options
      end

      def parse(args)
        option_parser.order!(args)
      end

      def command
        @command ||= load_command('generate').new
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
