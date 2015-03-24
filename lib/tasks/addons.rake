namespace :addons do
  task :u do
    require 'bundler'
    runtime_deps = []
    development_deps = []
    root_dir = File.dirname(__FILE__) + "/../.."
    gemfiles = Dir[root_dir + "/addons/*/*Gemfile"]
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
