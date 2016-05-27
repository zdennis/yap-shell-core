require 'pathname'

module Yap
  class World
    module UserAddons
    end

    module AddonMethods
      module ClassMethods
        def load_addon
          # no-op, override in subclass if you need to do anything special
          # when your addon is first loaded when the shell starts
        end

        def addon_name
          @addon_name ||= self.name.split(/::/).last.scan(/[A-Z][^A-Z]+/).map(&:downcase).reject{ |f| f == "addon" }.join("_").to_sym
        end

        def debug_log(msg)
          Treefell['addons'].puts "addon=#{addon_name} #{msg}"
        end

        def require(name)
          Treefell['shell'].puts "addon is requiring: #{name}"
          directory = File.dirname caller[0].split(':').first
          lib_path = File.join directory, "lib"
          support_file = File.join lib_path, "#{name}.rb"
          namespace = self.name.split('::').reduce(Object) do |context,n|
            o = context.const_get(n)
            break o if o.is_a?(Namespace)
            o
          end
          if File.exists?(support_file) && namespace
            Treefell['shell'].puts "#{name} is found in addon, loading #{support_file} in context of #{namespace}"
            namespace.module_eval IO.read(support_file), support_file, lineno=1
          else
            Treefell['shell'].puts "#{name} not found in addon, falling back to super"
            super(name)
          end
        end
      end

      module InstanceMethods
        def addon_name
          @addon_name ||= self.class.addon_name
        end

        def debug_log(msg)
          self.class.debug_log(msg)
        end
      end
    end

    module Namespace
    end

    class Addon
      extend AddonMethods::ClassMethods
      include AddonMethods::InstanceMethods
    end

    module Addons
      def self.syntax_ok?(file)
        `ruby -c #{file}`
        ($?.exitstatus == 0).tap do |result|
          Treefell['shell'].puts "is syntax ok?(#{file.inspect}) #{result}"
        end
      end

      def self.load_rcfiles(files)
        Treefell['shell'].puts %|searching for rcfiles:\n  * #{files.join("\n  * ")}|
        files.map do |file|
          if File.exists?(file)
            Treefell['shell'].puts "rcfile #{file} found, loading."
            RcFile.new file
          else
            Treefell['shell'].puts "rcfile #{file} not found, skipping."
          end
        end.flatten.compact
      end

      def self.load_directories(search_paths)
        Treefell['shell'].puts %|searching for addons in:\n  * #{search_paths.join("\n  * ")}|
        search_paths.map do |directory|
          Dir["#{directory}/*"].map do |d|
            if File.directory?(d)
              Treefell['shell'].puts %|addon found: #{d}|
              load_directory(d).map(&:new)
            else
              Treefell['shell'].puts %|file found in add-on search path, skipping.|
              nil
            end
          end
        end.flatten.compact
      end

      class RcFile < Addon
        attr_reader :file

        def initialize(file)
          @file = File.expand_path(file)
        end

        def initialize_world(world)
          Treefell['shell'].puts "initializing rcfile: #{file}"
          world.instance_eval File.read(@file), @file
        end
      end

      def self.load_directory(directory)
        directory = File.expand_path(directory)
        Treefell['shell'].puts "loading addon from directory: #{directory}"
        namespace = File.basename(directory).
          split(/[_-]/).
          map(&:capitalize).join
        namespace = "#{namespace}Addon"

        if Yap::World::UserAddons.const_defined?(namespace)
          raise LoadError, "#{namespace} is already defined! Failed loading #{file}"
        end

        # Create a wrapper module for every add-on. This is to eliminate
        # namespace collision.
        addon_module = Module.new do
          extend Namespace
          extend AddonMethods::ClassMethods
          const_set :Addon, Addon
        end

        Yap::World::UserAddons.const_set namespace, addon_module
        Treefell['shell'].puts "creating addon namespace: Yap::World::UserAddons::#{namespace}"

        lib_path = File.join directory, "lib"
        Treefell['shell'].puts "prepending addon path to $LOAD_PATH: #{lib_path}"
        $LOAD_PATH.unshift lib_path

        gemfiles = Dir["#{directory}/Gemfile"]
        Treefell['shell'].puts "looking for Gemfile in #{namespace} addon directory: #{directory}"
        if gemfiles.any?
          gemfiles.each do |gemfile|
            Treefell['shell'].puts "loading #{gemfile} for addon"
            eval File.read(gemfile)
          end
        else
          Treefell['shell'].puts "No Gemfile found for #{namespace} addon"
        end

        Dir["#{directory}/*.rb"].map do |addon_file|
          load_file(addon_file, namespace:namespace, dir:directory, addon_module:addon_module)
        end
      ensure
        if lib_path
          Treefell['shell'].puts "Removing addon #{lib_path} path from $LOAD_PATH"
          $LOAD_PATH.delete(lib_path)
        end
      end

      def self.load_file(file, dir:, namespace:, addon_module:)
        Treefell['shell'].puts "loading #{namespace} addon file: #{file}"
        klass_name = file.sub(dir, "").
          sub(/^#{Regexp.escape(File::Separator)}/, "").
          sub(File.extname(file.to_s), "").
          split(File::Separator).
          map{ |m| m.split(/[_-]/).map(&:capitalize).join }.
          join("::")

        addon_module.module_eval IO.read(file), file, lineno=1

        klass_name.split("::").reduce(addon_module) do |ns,name|
          if ns.const_defined?(name)
            ns.const_get(name)
          else
            raise("Did not find #{klass_name} in #{file}")
          end
        end.tap do |loaded_addon|
          Treefell['shell'].puts "loaded #{File.dirname(file)} as #{loaded_addon.inspect}"
        end
      end
    end
  end
end
