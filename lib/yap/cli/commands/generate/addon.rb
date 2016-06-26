require 'fileutils'
require 'term/ansicolor'

module Yap
  module Cli
    module Commands
      class Generate::Addon
        attr_accessor :addon_name, :version

        def initialize(addon_name)
          @addon_name = addon_name.gsub(/[^\w\-_]+/, '-').downcase
          @version = '0.1.0'
        end

        def doing(text, &block)
          print "#{text}"
          block.call
          puts " #{Term::ANSIColor.green('done')}"
        end

        def process
          puts "Creating addon #{Term::ANSIColor.yellow(addon_name)} in #{addon_dir}/"
          puts

          readme_path = File.join('README.md')
          lib_path = File.join('lib')
          lib_addon_path = File.join(lib_path, addon_dir)
          version_path = File.join(lib_addon_path, 'version.rb')
          addonrb_path = File.join(lib_path, "#{addon_dir}.rb")

          doing("    Create directory #{addon_dir}"){ FileUtils.mkdir_p addon_dir }
          Dir.chdir addon_dir do
            doing("    Create directory: #{lib_path}"){ FileUtils.mkdir_p lib_path }
            doing("    Creating file: #{gemspec_name}"){ File.write gemspec_name, gemspec_contents }
            doing("    Creating file: #{readme_path}"){ File.write readme_path, readme_contents }
            doing("    Creating file: #{addonrb_path}"){ File.write addonrb_path, libfile_contents }
            doing("    Create directory: #{lib_addon_path}"){ FileUtils.mkdir_p lib_addon_path }
            doing("    Creating file: #{version_path}"){ File.write version_path, version_contents }
          end

          puts
          puts "Yap addon generated! A few helpful things to note:"
          puts
          puts <<-TEXT.gsub(/^\s*\|/, '')
            |  * The #{Term::ANSIColor.yellow(addon_name)} addon is a standard rubygem and has its own gemspec, found in #{addon_dir}/
            |  * Yap loads the #{Term::ANSIColor.yellow(addon_constant_name)}, found in #{addonrb_path}
            |  * Share your addon with others by building a gem and pushing it to rubygems
            |
            |For more information see https://github.com/zdennis/yap-shell/wiki/Addons
          TEXT
          puts
        end

        private

        def addon_dir
          gem_safe_addon_name
        end

        def addon_constant_name
          [constant_name, 'Addon'].join('::')
        end

        def constant_name
          gem_safe_addon_name.split(/\W+/).map(&:capitalize).join
        end

        def gemspec_name
          "#{gem_safe_addon_name}.gemspec"
        end

        def gemspec_contents
          contents = File.read(File.dirname(__FILE__) + '/gemspec.template')
          contents % gemspec_template_variables
        end

        def gem_safe_addon_name
          "yap-shell-#{addon_name}-addon"
        end

        def gemspec_template_variables
          {
            addon_dir: addon_dir,
            constant_name: constant_name,
            summary: "#{addon_name} summary goes here.",
            description: "#{addon_name} description goes here.",
            license: 'MIT',
            authors: [],
            email: 'you@example.com',
            homepage: ''
          }
        end

        def libfile_contents
          export_as = addon_name
          export_as = "'#{addon_name}'" if addon_name =~ /-/
          <<-RUBY.gsub(/^\s*\|/, '')
            |module #{constant_name}
            |  class Addon < ::Yap::World::Addon
            |    self.export_as :#{export_as}
            |
            |    def initialize_world(world)
            |      @world = world
            |
            |      # Initialize your addon here.
            |    end
            |  end
            |end
          RUBY
        end

        def readme_contents
          <<-MARKDOWN

          MARKDOWN
        end

        def version_contents
          <<-RUBY.gsub(/^\s*\|/, '')
            |module #{constant_name}
            |  VERSION = '#{version}'
            |end
          RUBY
        end
      end
    end
  end
end
