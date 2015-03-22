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

        def require(name)
          directory = File.dirname caller[0].split(':').first
          lib_path = File.join directory, "lib"
          support_file = File.join lib_path, "#{name}.rb"
          namespace = self.name.split('::').reduce(Object) do |context,n|
            o = context.const_get(n)
            break o if o.is_a?(Namespace)
            o
          end
          if File.exists?(support_file) && namespace
            namespace.module_eval IO.read(support_file), support_file, lineno=1
          else
            super(name)
          end
        end
      end

      module InstanceMethods
        def addon_name
          @addon_name ||= self.class.addon_name
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
        $?.exitstatus == 0
      end

      def self.load_rcfiles(files)
        files.map do |file|
          RcFile.new IO.read(file)
        end
      end

      def self.load_directories(directories)
        directories.map do |d|
          next unless File.directory?(d)
          load_directory(d).map(&:new)
        end.flatten
      end

      class RcFile < Addon
        def initialize(contents)
          @contents = contents
        end

        def initialize_world(world)
          world.instance_eval @contents
        end
      end

      def self.load_directory(directory)
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

        lib_path = File.join directory, "lib"
        $LOAD_PATH.unshift lib_path
        Dir["#{directory}/*.rb"].map do |addon_file|
          load_file(addon_file, namespace:namespace, dir:directory, addon_module:addon_module)
        end
      ensure
        $LOAD_PATH.delete(lib_path) if lib_path
      end

      def self.load_file(file, dir:, namespace:, addon_module:)
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
        end
      end
    end
  end
end
