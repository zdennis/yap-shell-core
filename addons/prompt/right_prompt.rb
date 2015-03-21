require 'terminfo'

class Prompt
  class RightPrompt
    include Term::ANSIColor

    def self.load_addon
      @instance ||= new
    end

    def initialize_world(world)
      @world = world
      Thread.new do
        loop do
          sleep 1
          begin
            raise ArgumentError
          rescue => ex
            puts ex.message
            puts ex.backtrace
          end
          # @world.prompt.right_text = Time.now.strftime("%H:%M:%S")
        end
      end
    end
  end
end
