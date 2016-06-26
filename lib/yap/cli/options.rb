require 'pathname'
require 'yap/cli/options'

module Yap
  module Cli
    module OptionsLoader

      def load_command(path)
        load_constant_from_path Pathname.new('yap/cli/commands').join(path)
      end

      def load_constant_from_path(path)
        requiring_parts = []
        path_parts = path.to_s.split('/')
        constant = path_parts.reduce(Object) do |constant, part|
          requiring_parts << part
          requiring_path = requiring_parts.join('/')
          require requiring_path
          part = part.capitalize
          if constant.const_defined?(part)
            constant = constant.const_get(part)
          else
            fail "Couldn't find #{part} in #{constant}"
          end
        end
        Treefell['shell'].puts "#{inspect} loaded: #{constant}"
        constant
      end

      def load_relative_constant(path_str)
        base_path = self.class.name.downcase.gsub(/::/, '/')
        require_path = Pathname.new(base_path)
        load_constant_from_path require_path.join(path_str).to_s
      end
    end

    class Options
      include OptionsLoader

      attr_reader :options

      def initialize(options: {})
        @options = options
        @commands = []
      end

      def [](key)
        @options[key]
      end

      def commands
        @commands.dup.freeze
      end

      def parse(args)
        option_parser.order!(args)

        Yap.configuration.run_shell = false if args.any?

        scope = []
        require_path = Pathname.new("yap/cli/options")
        args_processed = []

        while args.any?
          if args_processed == args
            puts "Unknown option(s*): #{scope.concat([args.first]).join(' ')}"
            exit 1
          end
          args_processed = args.dup

          option_str = args.shift
          current_scope = scope + [option_str]

          begin
            options_class = load_relative_constant current_scope.join('/')
            options_instance = options_class.new(options: options)
            options[:option] = options_instance
            options_instance.parse(args)
            @commands << options_instance.command

            scope << option_str
          rescue LoadError => ex
            puts "Unknown option(s=): #{option_str}"
            puts ex.inspect
            puts ex.backtrace
            exit 1
          end
        end
      end

      private

      def option_parser
        OptionParser.new do |opts|
          opts.on('-h', '--help', 'Prints this help') do
            puts opts
            exit
          end

          opts.on('--skip-first-time', 'Disables creating ~/.yap directory on shell startup') do
            Yap.configuration.skip_first_time = true
          end

          opts.on('--addon-paths=PATHS', 'Paths to directories containing addons (comma-separated). This overwrites the default addon paths.') do |paths|
            Yap.configuration.addon_paths = paths.split(',').map(&:strip)
          end

          opts.on('--no-addons', 'Disables auto-loading addons on shell startup') do
            Yap.configuration.use_addons = false
          end

          opts.on('--no-history', 'Disables auto-loading or saving history') do
            Yap.configuration.use_history = false
          end

          opts.on('--rcfiles=PATHS', 'Paths to Yap rcfiles in the order they should load (comma-separated). This overwrites the default rcfiles.') do |paths|
            Yap.configuration.rcfiles = paths.split(',').map(&:strip)
          end

          opts.on('--no-rcfiles', 'Disables auto-loading rcfiles on shell startup') do
            Yap.configuration.use_rcfiles = false
          end
        end
      end
    end
  end
end
