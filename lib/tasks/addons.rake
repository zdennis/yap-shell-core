namespace :addons do
  task :new do
    require 'highline'
    require 'term/ansicolor'
    require 'pathname'

    extend Term::ANSIColor

    yap_path = Pathname.new(File.dirname(__FILE__)).join('../..')
    yap_lib_path = yap_path.join('lib')
    yap_addons_path = yap_path.join('addons')

    $LOAD_PATH.unshift yap_lib_path
    require 'yap'

    cli = HighLine.new
    answer = cli.ask("Name for the addon? ")

    addon_name = answer.downcase.gsub(/\W+/, '_')
    addon_class_name = addon_name.split('_').map(&:capitalize).join
    addon_path = yap_addons_path.join(addon_name)

    loop do
      answer = cli.ask("Create #{addon_class_name} addon in #{addon_path}? [Yn] ")
      break if answer =~ /y/i
      exit 1 if answer =~ /n/i
    end
    puts "Generating #{addon_class_name}"
    puts

    print "  Creating #{addon_path} "
    FileUtils.mkdir_p addon_path
    puts green('done')

    addon_file = addon_path.join("#{addon_name}.rb")
    print "  Creating #{addon_file} "
    File.write addon_file, <<-FILE.gsub(/^\s*\|/, '')
      |class #{addon_class_name} < Addon
      |  def initialize_world(world)
      |    # initialization code here
      |  end
      |end
    FILE
    puts green('done')
    puts
  end

  namespace :update do
    desc "Update the gemspec based on add-on specific dependnecies"
    task :gemspec do
      require 'bundler'
      runtime_deps = []
      development_deps = []
      root_dir = File.dirname(__FILE__) + "/../.."
      gemfiles = Dir[root_dir + "/addons/**/**/Gemfile"]
      gemfiles.each do |gemfile|
        bd = Bundler::Definition.build(gemfile, nil, nil)
        runtime_deps.push *bd.dependencies.select{ |dep| dep.type == :runtime }
        development_deps.push *bd.dependencies.select{ |dep| dep.type == :development }
      end

      runtime_h = Hash.new{ |h,name| h[name] = Gem::Dependency.new(name) }
      runtime_deps.each { |dep| runtime_h[dep.name] = runtime_h[dep.name].merge(dep) }

      dev_h = Hash.new{ |h,name| h[name] = Gem::Dependency.new(name) }
      development_deps.each { |dep| dev_h[dep.name] = dev_h[dep.name].merge(dep) }

      deps_str = ""
      deps_str << runtime_h.map do |name, dep|
        if dep.requirement.none?
          %|  spec.add_dependency "#{dep.name}"|
        else
          %|  spec.add_dependency "#{dep.name}", "#{dep.requirement.as_list.first}"|
        end
      end.join("\n")

      deps_str << dev_h.map do |name, dep|
        if dep.requirement.none?
          %|  spec.add_development_dependency "#{dep.name}"|
        else
          %|  spec.add_development_dependency "#{dep.name}", "#{dep.requirement.as_list.first}"|
        end
      end.join("\n")

      gemspec = Dir[root_dir + "/*.gemspec"].first || raise("No gemspec found in directory: #{root_dir}")
      gemspec = File.expand_path(gemspec)
      contents = File.read(gemspec)
      new_contents = contents.sub(/(\#--BEGIN_ADDON_GEM_DEPENDENCIES--\#)\s*.*(^.*\#--END_ADDON_GEM_DEPENDENCIES--\#)/mx) do
        "#{$1}\n#{deps_str}\n#{$2}"
      end

      File.write(gemspec, new_contents)
      puts "Updated #{gemspec}"
      puts new_contents
    end
  end
end
