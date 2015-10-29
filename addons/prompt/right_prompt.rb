class RightPrompt < Addon
  include Term::ANSIColor

  def self.load_addon
    @instance ||= new
  end

  def initialize_world(world)
    @world = world
    Thread.new do
      loop do
        @world.right_prompt_text = Time.now.strftime("%H:%M:%S")
        sleep 1
      end
    end
  end
end
