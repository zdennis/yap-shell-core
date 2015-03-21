require 'pathname'

module Yap
  class World
    module UserAddons
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
          load_directory(d).map(&:load_addon)
        end.flatten
      end

      class RcFile
        def initialize(contents)
          @contents = contents
        end

        def load_addon
          self
        end

        def initialize_world(world)
          world.instance_eval @contents
        end
      end

      def self.load_directory(directory)
        namespace = File.basename(directory).
          split(/[_-]/).
          map(&:capitalize).join

        if Yap::World::UserAddons.const_defined?(namespace)
          raise LoadError, "#{namespace} is already defined! Failed loading #{file}"
        end

        # Create a wrapper module for every add-on. This is to eliminate
        # namespace collision.
        addon_module = Yap::World::UserAddons.const_set namespace, Module.new

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
