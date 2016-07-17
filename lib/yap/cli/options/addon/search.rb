module Yap
  module Cli
    module Options
      class Addon::Search < Base
        def parse(args)
          search_terms = []
          while args.any?
            option_parser.order!(args)
            search_terms << args.shift
          end
          command.search_term = search_terms.shift
        end

        def command
          @command ||= load_command('addon/search').new
        end

        def help_message
          option_parser.to_s
        end

        private

        def option_parser
          OptionParser.new do |opts|
            opts.banner = <<-TEXT.gsub(/^\s*\|/, '')
              |Usage: #{opts.program_name} addon search [options] [addon-name]
              |
              |#{Colors.cyan('yap addon search')} can be used to search for yap addons.
              |
              |Addon search options:
            TEXT

            opts.on('-h', '--help', 'Prints this help') do
              puts opts
              puts
              puts  <<-TEXT.gsub(/^\s*\|/, '')
                |Example: Search for an addon
                |
                |   #{opts.program_name} addon search --local foo
                |
                |Example: Search for an addon locally (no network access)
                |
                |   #{opts.program_name} addon search foo
                |
              TEXT
              exit 0
            end
            opts.on('--local', 'Search locally, no network access') do
              command.local = true
            end
            opts.on('-a', '--all', 'Display all addon versions') do
              command.all = true
            end
            opts.on('--prerelease', 'Display prerelease versions') do
              command.prerelease = true
            end
            opts.on('--gem-name', 'Display rubygem name instead of shortened yap addon name') do
              command.show_gem_name = true
            end
            opts.on('-v', '--version VERSION', 'Specify version of addon to search') do |version|
              command.version = version
            end
          end
        end
      end
    end
  end
end
