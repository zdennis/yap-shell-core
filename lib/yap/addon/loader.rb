module Yap
  module Addon
    class Loader
      def initialize(addon_references)
        @addon_references = addon_references
      end

      def load_all
        @addon_references.map do |reference|
          load_reference(reference)
        end
      end

      private

      def bring_addon_into_existence(reference)
        require reference.require_as
        classified_name = reference.require_as.split('-').map(&:capitalize).join
        unless Object.const_defined?(classified_name)
          fail LoadError, "Expected #{name}.rb to load #{classified_name}, but it didn't"
        end

        addon = Object.const_get(classified_name)
        addon_class = if addon.is_a?(Addon)
          addon
        elsif addon.const_defined?(:Addon)
          addon.const_get(:Addon)
        else
          fail LoadError, 'Expected gem #{name} to define a constant, but nothing was found'
        end
        addon_class.new enabled: reference.enabled?
      end

      def load_reference(reference)
        gem reference.require_as
        bring_addon_into_existence reference
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

    end
  end
end
