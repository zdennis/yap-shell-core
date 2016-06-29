module Yap
  module Addon
    class RcFile < Yap::Addon::Base
      attr_reader :file

      def initialize(file)
        super(enabled: true)
        @file = File.expand_path(file)
      end

      def addon_name
        @file
      end

      def initialize_world(world)
        Treefell['shell'].puts "initializing rcfile: #{file}"
        world.instance_eval File.read(@file), @file
      end
    end
  end
end
