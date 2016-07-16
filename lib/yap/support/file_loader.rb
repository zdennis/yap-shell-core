module Yap
  module Support

    # FileLoader is for loading constants from a given path. See
    #
    # Given a path, load all files/constants necessary to get the end
    # result.
    #
    # For example, the following with try to load Yap::Cli::Options::Addon:
    #
    #     file_loader = FileLoader.new(
    #       path: 'yap/cli/options/addon',
    #       root: '/absolute/path/to/yap/lib'
    #     )
    #     file_loader.constant # => Yap::Cli::Options::Addon
    #
    # It will load each path part and try to expects to find a matching
    # constant at each step.
    #
    class FileLoader
      class ConstantNotFound < ::StandardError ; end

      def self.load_constant_from_path(path)
        new(path: path, root: Yap.root).constant
      end

      attr_reader :path, :root

      def initialize(path: , root:)
        @path = path
        @root = root
      end

      def constant
        requiring_parts = []

        # Start at Object, then iterate over the path_parts building up
        # the files/constants to load at each step.
        constant = path_parts.reduce(Object) do |constant, path_part|
          requiring_parts << path_part
          file = root.join('lib', requiring_parts.join('/') + '.rb')
          constant_name = path_part.capitalize

          if File.exists?(file)
            require file
          end

          if constant.const_defined?(constant_name)
            constant.const_get(constant_name)
          else
            fail ConstantNotFound, "Expected to find #{constant_name}, but did not. Is it defined?"
          end
        end
        Treefell['shell'].puts "#{inspect} loaded: #{constant}"
        constant
      end

      private

      def path_parts
        path.to_s.split('/')
      end
    end
  end
end
