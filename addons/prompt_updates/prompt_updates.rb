class PromptUpdates < Addon
  attr_reader :world

  def initialize_world(world)
    current_branch = determine_branch

    @world = world
    @world.events.recur(
      name: 'prompt_updates',
      source: self,
      interval_in_ms: 100
    ) do
      new_branch = determine_branch
      if current_branch != new_branch
        current_branch = new_branch
        @world.refresh_prompt
      end
    end

  end

  private

  def determine_branch
    `git branch`.scan(/\*\s*(.*)$/).flatten.first
  end

end
