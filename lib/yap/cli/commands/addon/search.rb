module Yap
  module Cli
    module Commands
      class Addon::Search
        attr_accessor :all, :local, :prerelease, :search_term, :version
        attr_accessor :show_gem_name

        def process
          options = []

          if search_term.nil?
            puts "No addons found. Please provide a search term."
          end

          options << '--all' if all
          options << '--local' if local
          options << '--prerelease' if prerelease
          options << "--version #{version}" if version

          print_addons gem_search(options)
        end

        def extract_gem_names_from_search(search_results)
          search_results.lines.map(&:chomp).map do |line|
            results = line.scan(/^(yap-shell-addon-(\S+))\s*\((\d+\.\d+\.\d+)\)/)
            gem_name, _, _ = results.flatten
            gem_name
          end.compact
        end

        def gem_search(options)
          search_results = `gem search #{options.join(' ')} yap-shell | grep #{search_term}`
          gem_names = extract_gem_names_from_search search_results
          gem_specs_for_gems gem_names
        end

        def gem_specs_for_gems(gem_names)
          options = []
          options << (local ? '-l' : '-r')
          options << "--version #{version}" if version
          gem_names.map do |gem_name|
            YAML.load `gem spec #{options.join(' ')} #{gem_name}`
          end
        end

        def print_addons(gemspecs)
          headers = {
            name: (show_gem_name ? "Rubygem" : "Addon Name"),
            version: "Version",
            date: "Date Released",
            author: "Author",
            summary: "Summary"
          }
          value_for = {
            name: -> (s) {
              if show_gem_name
                s.name
              else
                s.name.scan(/^yap-shell-addon-(\S+)/).flatten.first
              end
            },
            version: -> (s) { s.version.to_s },
            date: -> (s) { s.date.to_date.to_s },
            author: -> (s) { s.author },
            summary: -> (s) { s.summary }
          }

          longest = {
            name: gemspecs.map{ |s| value_for[:name].call(s) }.concat(Array(headers[:name])).map(&:length).max,
            version: gemspecs.map{ |s| value_for[:version].call(s) }.concat(Array(headers[:version])).map(&:length).max,
            date: gemspecs.map{ |s| value_for[:date].call(s) }.concat(Array(headers[:date])).map(&:length).max,
            author: gemspecs.map{ |s| value_for[:author].call(s) }.concat(Array(headers[:author])).map(&:length).max,
            summary: gemspecs.map{ |s| value_for[:summary].call(s) }.concat(Array(headers[:summary])).map(&:length).max
          }

          spacing = "  "
          format_string = longest.reduce([]) do |str, (key, maxlength)|
            str << "%-#{maxlength}s"
          end.join(spacing)

          output = gemspecs.map do |gemspec|
            values = longest.keys.map { |key| value_for[key].call(gemspec) }
            sprintf "#{format_string}", *values
          end
          output = output.join("\n")

          highlighted_output = output.gsub(/(#{Regexp.escape(search_term)})/) do
            Colors.cyan($1)
          end

          puts Colors.bright_black(
            sprintf("#{format_string}", *longest.keys.map { |key| headers[key] })
          )
          puts highlighted_output
        end
      end
    end
  end
end
