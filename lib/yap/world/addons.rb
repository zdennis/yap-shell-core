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
          Treefell['shell'].puts "#{self}.#{__callee__} enter with: #{name.inspect}"
          directory = File.dirname caller[0].split(':').first
          lib_path = File.join directory, "lib"
          support_file = File.join lib_path, "#{name}.rb"
          Treefell['shell'].puts "#{self}.#{__callee__} determining if #{name.inspect} should be scoped to addon"
          namespace = self.name.split('::').reduce(Object) do |context,n|
            o = context.const_get(n)
            break o if o.is_a?(Namespace)
            o
          end
          if File.exists?(support_file) && namespace
            Treefell['shell'].puts "#{self}.#{__callee__}(#{name.inspect}) found in addon, loading #{support_file.inspect} into #{namespace}"
            namespace.module_eval IO.read(support_file), support_file, lineno=1
          else
            Treefell['shell'].puts "#{self}.#{__callee__} not found in addon, falling back to super(#{name.inspect})"
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
        ($?.exitstatus == 0).tap do |result|
          Treefell['shell'].puts "#{self}.#{__callee__} syntax_ok?(#{file.inspect}) #{result}"
        end
      end

      def self.load_rcfiles(files)
        Treefell['shell'].puts "#{self}.#{__callee__} enter with: #{files.inspect}"
        files.map do |file|
          if File.exists?(file)
            RcFile.new file
          else
            Treefell['shell'].puts "#{self}.#{__callee__} skipping #{file.inspect}, does not exist"
          end
        end.flatten.compact
      end

      def self.load_directories(directories)
        Treefell['shell'].puts "#{self}.#{__callee__} enter with: #{directories.inspect}"
        directories.map do |d|
          if File.directory?(d)
            load_directory(d).map(&:new)
          else
            Treefell['shell'].puts "#{self}.#{__callee__} skipping #{d.inspect}, not a directory."
          end
        end.flatten.compact.tap do |results|
          Treefell['shell'].puts "#{self}.#{__callee__} returning with: #{results.inspect}"
        end
      end

      class RcFile < Addon
        attr_reader :file

        def initialize(file)
          @file = file
        end

        def initialize_world(world)
          Treefell['shell'].puts "#{self.class}(#{file.inspect})##{__callee__}"
          world.instance_eval File.read(@file)
        end
      end

      def self.load_directory(directory)
        directory = File.expand_path(directory)
        Treefell['shell'].puts "#{self}.#{__callee__} enter with: #{directory.inspect}"
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
        Treefell['shell'].puts "#{self}.#{__callee__} loading addon into namespace: Yap::World::UserAddons::#{namespace}"

        lib_path = File.join directory, "lib"
        Treefell['shell'].puts "#{self}.#{__callee__} prepending path to $LOAD_PATH: #{lib_path}"
        $LOAD_PATH.unshift lib_path

        gemfiles = Dir["#{directory}/Gemfile"]
        gemfiles.each do |gemfile|
          Treefell['shell'].puts "#{self}.#{__callee__} evaluating Gemfile: #{gemfile}"
          eval File.read(gemfile)
        end

        Dir["#{directory}/*.rb"].map do |addon_file|
          load_file(addon_file, namespace:namespace, dir:directory, addon_module:addon_module)
        end.tap do |results|
          Treefell['shell'].puts "#{self}.#{__callee__} returning with #{results.inspect}"
        end
      ensure
        if lib_path
          Treefell['shell'].puts "#{self}.#{__callee__} removing path from $LOAD_PATH: #{lib_path}"
          $LOAD_PATH.delete(lib_path)
        end
      end

      def self.load_file(file, dir:, namespace:, addon_module:)
        Treefell['shell'].puts "#{self}.#{__callee__} enter with #{file}, dir: #{dir.inspect}, namespace: #{namespace.inspect}, addon_module: #{addon_module}"
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
          Treefell['shell'].puts "#{self}.#{__callee__} returning with addon loaded: #{loaded_addon.inspect}"
        end
      end
    end
  end
end
