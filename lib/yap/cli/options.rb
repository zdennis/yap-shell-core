require 'pathname'

module Yap
  module Cli
    module Options
      class Base
        attr_reader :options

        def initialize(options:)
          @options = options
        end

        def load_command(path)
          load_constant_from_path Pathname.new('yap/cli/commands').join(path)
        end

        def load_constant_from_path(path)
          ::Yap::Support::FileLoader.load_constant_from_path(path)
        end

        def load_relative_constant(path_str)
          base_path = self.class.name.downcase.gsub(/::/, '/')
          require_path = Pathname.new(base_path)
          load_constant_from_path require_path.join(path_str).to_s
        end
      end
    end
  end
end

require 'yap/cli/options/main'
