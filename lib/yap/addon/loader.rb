module Yap
  module Addon
    module Loader
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
          loading_a_gem = false
          Dir["#{directory}/*"].map do |d|
            if File.directory?(d)
              if File.expand_path(d) =~ /#{Gem.path.map{|path| Regexp.escape(path)}.join('|')}/
                loading_a_gem = true
              else
                loading_a_gem = false
              end

              if File.basename(d) =~ /(yap-shell-addon-.*)-\d+(\.\d+)*$/
                addon_name = $1
                if loading_a_gem
                  load_gem(addon_name).tap do |addon|
                    Treefell['shell'].puts %|Loaded addon instance: #{addon}|
                  end
                else
                  Treefell['shell'].puts %|non-gem addon found: #{d}|
                  load_non_gem(addon_name, d)
                end
              end
            else
              Treefell['shell'].puts %|file found in add-on search path, skipping.|
              nil
            end
          end
        end.flatten.compact
      end

      class RcFile < Yap::Addon::Base
        attr_reader :file

        def initialize(file)
          @file = File.expand_path(file)
        end

        def initialize_world(world)
          Treefell['shell'].puts "initializing rcfile: #{file}"
          world.instance_eval File.read(@file), @file
        end
      end

      def self.load_non_gem(name, directory)
        directory = File.expand_path(directory)
        Treefell['shell'].puts "loading addon #{name} from directory: #{directory}"

        lib_path = File.join directory, "lib"
        Treefell['shell'].puts "prepending addon path to $LOAD_PATH: #{lib_path}"
        $LOAD_PATH.unshift lib_path

        bring_addon_into_existence(name)
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

      def self.load_gem(name)
        gem name
        bring_addon_into_existence(name)
      end

      def self.bring_addon_into_existence(name)
        require name
        classified_name = name.split('-').map(&:capitalize).join
        unless Object.const_defined?(classified_name)
          fail "Expected #{name}.rb to load #{classified_name}, but it didn't"
        end
        addon = Object.const_get(classified_name)
        if addon.is_a?(Addon)
          addon.new
        elsif addon.const_defined?(:Addon)
          addon.const_get(:Addon).new
        else
          fail 'Expected gem #{name} to define a constant, but nothing was found'
        end
      end
    end
  end
end
