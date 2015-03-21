require 'terminfo'

module Yap
  module World::Addons
    module Prompt
      class RightPrompt
        include Term::ANSIColor

        def self.load_addon
          @instance ||= new
        end

        def initialize_world(world)
          @world = world
          Thread.new do
            loop do
              sleep 0.25
              @world.prompt.right_text = Time.now.strftime("%H:%M:%S")
            end
          end
        end
      end
    end
  end
end
