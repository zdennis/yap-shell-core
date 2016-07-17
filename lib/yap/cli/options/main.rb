module Yap
  module Cli
    module Options
      class Main < Base
        def initialize(config: Yap.configuration, options: {}, options_dir: 'yap/cli/options')
          super(options: options)
          @config = config
          @commands = []
          @options_dir = options_dir
        end

        def commands
          @commands.dup.freeze
        end

        def parse(args)
          option_parser.order!(args)
          options_instance = self

          @config.run_shell = false if args.any?

          scope = ['..']
          require_path = Pathname.new(@options_dir)
          args_processed = []

          while args.any?
            if args_processed == args
              puts "Unknown option(s): #{scope.concat([args.first]).join(' ')}"
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
              puts "Unknown option: #{option_str}"
              puts
              puts options_instance.help_message
              exit 1
            end
          end
        end

        def help_message
          option_parse.to_s
        end

        private

        def option_parser
          OptionParser.new do |opts|
            opts.banner = <<-TEXT.gsub(/^\s*\|/, '')
              |Usage: #{opts.program_name} [option|command]
              |
              |When a command is omitted the yap shell starts an interactive
              |session. Otherwise, the command is executed.
              |
              |Shell options:
            TEXT
            opts.on('-h', '--help', 'Prints this help') do
              puts opts
              commands = Dir[ file_utils.dirname(__FILE__) + '/commands/*.rb' ].map do |path|
                command = file_utils.basename(path).sub(/\.rb$/, '')
                "#{command}: #{Colors.cyan(opts.program_name + ' ' + command + ' --help')}"
              end
              commands = %|  #{commands.join("\n  ")}|
              puts <<-TEXT.gsub(/^\s*\|/, '')
                |
                |Commands:
                |
                |#{commands}
                |
              TEXT
              exit 0
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
end
