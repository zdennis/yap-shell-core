module Yap
  class World
    module Addons
      def self.syntax_ok?(file)
        `ruby -c #{file}`
        $?.exitstatus == 0
      end

      def self.load_addons_from_files(dir:, files:[])
        files.map do |file|
          (puts "Cannot load world addon: #{file} does not exist" and next) unless File.exist?(file)
          (puts "Cannot load world addon: #{file} is not readable" and next) unless File.exist?(file)
          (puts "Cannot load world addon: #{file} is a directory file" and next) if File.directory?(file)

          addon = file.end_with?("rc") ? load_rcfile(file:file) : load_addon_file(dir:dir, file:file)
          addon.load_addon
        end
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

      def self.load_rcfile(file:)
        RcFile.new IO.read(file)
      end

      def self.load_addon_file(dir:, file:)
        name = file.sub(dir, "").
          sub(File.extname(file), "").
          split(File::Separator).
          map{ |m| m.split(/[_-]/).map(&:capitalize).join }.
          join("::")

        # name = File.basename(file).sub(dir, "").sub(File.extname(file), "").split(/[_]/).map(&:capitalize).join
        klass_name = "Yap::World::Addons::#{name}"

        load file

        klass_name.split("::").reduce(Object) do |namespace,name|
          if namespace.const_defined?(name)
            namespace.const_get(name)
          else
            raise("Did not find #{klass_name} in #{file}")
          end
        end
      end
    end
  end
end
