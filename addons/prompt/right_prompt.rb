class RightPrompt < Addon
  def self.load_addon
    @instance ||= new
  end

  def initialize_world(world)
    @world = world

    # @world.subscribe(:refresh_right_prompt) do |event|
    #   @world.right_prompt_text = Time.now.strftime("%H:%M:%S")
    # end
    #
    # @world.events.recur(
    #   name: "refresh_right_prompt", source: self, interval_in_ms: 1_000
    # )
  end
end
