require 'fileutils'
require 'term/ansicolor'

module Yap
  module Cli
    module Commands
      class Generate::Addon
        attr_accessor :addon_name, :version, :use_git

        def initialize(addon_name)
          @addon_name = addon_name.gsub(/[^\w\-_]+/, '-').downcase
          @version = '0.1.0'
          @use_git = true
        end

        def doing(text, &block)
          print "#{text}"
          block.call
          puts " #{Term::ANSIColor.green('done')}"
        end

        def process
          puts "Creating addon #{Term::ANSIColor.yellow(addon_name)} in #{addon_dir}/"
          puts

          mkdir addon_dir
          Dir.chdir addon_dir do
            mkdir lib_path
            write_file 'Gemfile', gemfile_contents
            write_file gemspec_name, gemspec_contents
            write_file 'LICENSE.txt', license_contents
            write_file 'Rakefile', rakefile_contents
            write_file 'README.md', readme_contents
            write_file addonrb_path, addonrb_contents
            mkdir lib_addon_path
            write_file version_path, version_contents

            puts
            if use_git && `which git` && $?.exitstatus == 0
              write_file '.gitignore', gitignore_contents
              doing "git init . && git add . && git commit -m 'initial commit of #{addon_name}'" do
                `git init . && git add . && git commit -m 'initial commit of #{addon_name} addon for yap'`
              end
            else
              puts "Git initialization #{Term::ANSIColor.cyan('skipped')}"
            end
          end

          puts
          puts "Yap addon generated! A few helpful things to note:"
          puts
          puts <<-TEXT.gsub(/^\s*\|/, '')
            |  * The #{Term::ANSIColor.yellow(addon_name)} addon has been generated in #{addon_dir}/
            |  * It is a standard rubygem, has its own gemspec, and is named #{Term::ANSIColor.yellow(gem_safe_addon_name)}
            |  * Yap loads the #{Term::ANSIColor.yellow(constant_name)}, found in #{addonrb_path} (start there)
            |  * Share your addon with others by building a gem and pushing it to rubygems
            |
            |For more information see https://github.com/zdennis/yap-shell/wiki/Addons
            |
            |Now, to get started:
            |
            |   cd #{gem_safe_addon_name}
          TEXT
          puts
        end

        private

        def mkdir(path)
          doing("Create directory: #{path}"){ FileUtils.mkdir_p path }
        end

        def write_file(path, contents)
          doing "Creating file: #{path}" do
            File.write path, contents
          end
        end

        def addon_dir
          gem_safe_addon_name
        end

        def addonrb_path
          File.join(lib_path, gem_safe_addon_name + '.rb')
        end

        def addonrb_contents
          contents = File.read(File.dirname(__FILE__) + '/addonrb.template')
          contents % addonrb_template_variables
        end

        def addonrb_template_variables
          export_as = addon_name
          export_as = "'#{addon_name}'" if addon_name =~ /-/
          {
            constant_name: constant_name,
            export_as: export_as
          }
        end

        def bundler_version
          require 'bundler/version'
          Bundler::VERSION.scan(/\d+\.\d+/).first ||
            fail('Cannot determine bundler version')
        end

        def constant_name
          gem_safe_addon_name.split(/\W+/).map(&:capitalize).join
        end

        def gemfile_contents
          <<-GEMFILE.gsub(/^\s*\|/, '')
            |source 'https://rubygems.org'
            |
            |# Specify your gem's dependencies in #{gemspec_name}
            |gemspec
          GEMFILE
        end

        def gem_safe_addon_name
          "yap-shell-addon-#{addon_name}"
        end

        def gemspec_name
          "#{gem_safe_addon_name}.gemspec"
        end

        def gemspec_contents
          contents = File.read(File.dirname(__FILE__) + '/gemspec.template')
          contents % gemspec_template_variables
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
            homepage: '',
            bundler_version: bundler_version,
            rake_version: rake_version,
            rspec_version: rspec_version,
            yap_version: yap_version
          }
        end

        def gitignore_contents
          <<-TEXT.gsub(/^\s*/, '')
            *.gem
            *.rbc
            .bundle
            .config
            .yardoc
            Gemfile.lock
            InstalledFiles
            _yardoc
            coverage
            doc/
            lib/bundler/man
            pkg
            rdoc
            spec/reports
            test/tmp
            test/version_tmp
            tmp
            *.bundle
            *.so
            *.o
            *.a
            mkmf.log
            wiki/
          TEXT
        end

        def lib_path
          File.join('lib')
        end

        def lib_addon_path
          File.join(lib_path, addon_dir)
        end

        def license_contents
          contents = File.read(File.dirname(__FILE__) + '/license.template')
          contents % license_template_variables
        end

        def license_template_variables
          username = (`git config user.name` rescue 'YOUR_NAME')
          { username: username }
        end

        def rake_version
          require 'rake/version'
          version_string = if Rake.const_defined?(:VERSION)
            Rake::VERSION
          else
            Rake::Version::NUMBERS.join('.')
          end
          version_string.scan(/\d+\.\d+/).first ||
            fail('Cannot determine rake version')
        end

        def rakefile_contents
          File.read(File.dirname(__FILE__) + '/rakefile.template')
        end

        def readme_contents
          contents = File.read(File.dirname(__FILE__) + '/readme.template')
          contents % readme_template_variables
        end

        def readme_template_variables
          {
            addon_name: addon_name,
            gem_safe_addon_name: gem_safe_addon_name,
            lib_addon_path: lib_addon_path,
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

        def rspec_version
          require 'rspec/version'
          RSpec::Version::STRING.scan(/\d+\.\d+/).first ||
            fail('Cannot determine rspec version')
        end

        def version_path
          File.join(lib_addon_path, 'version.rb')
        end

        def version_contents
          <<-RUBY.gsub(/^\s*\|/, '')
            |module #{constant_name}
            |  VERSION = '#{version}'
            |end
          RUBY
        end

        def yap_version
          Yap::Shell::VERSION.scan(/\d+\.\d+/).first ||
            fail('Cannot determine yap version')
        end
      end
    end
  end
end
