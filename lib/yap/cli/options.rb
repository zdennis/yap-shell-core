require 'pathname'
require 'yap/support/file_utils_helper'

module Yap
  module Cli
    module Options
      class Base
        include ::Yap::Support::FileUtilsHelper

        attr_reader :options

        def initialize(options:, stdout: $stdout, stderr: $stderr)
          @options = options
          @stdout = stdout
          @stderr = stderr
        end

        def load_command(path)
          load_constant_from_path Pathname.new('yap/cli/commands').join(path)
        end

        def load_constant_from_path(path)
          file_loader.load_constant_from_path(path)
        end

        def load_relative_constant(path)
          base_path = self.class.name.downcase.gsub(/::/, '/')
          require_path = Pathname.new(base_path)
          load_constant_from_path require_path.join(path).to_s
        end

        protected

        attr_reader :stdout, :stderr

        def puts(*args)
          stdout.puts *args
        end
      end
    end
  end
end

require 'yap/cli/options/main'
