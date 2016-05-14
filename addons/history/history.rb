class History < Addon
  attr_reader :file
  attr_reader :position

  def initialize_world(world)
    @world = world

    @file = world.configuration.path_for('history')
    @position = 0

    load_history

    world.func(:history) do |args:, stdin:, stdout:, stderr:|
      history_length = @world.editor.history.length
      first_arg = args.first.to_i
      size = first_arg > 0 ? first_arg + 1 : history_length

      # start from -2 since we don't want to include the current history
      # command being run.
      stdout.puts @world.editor.history[history_length-size..-2]
    end
  end

  def save
    debug_log "saving history file=#{file.inspect}"
    File.open(file, "a") do |file|
      # Don't write the YAML header because we're going to append to the
      # history file, not overwrite. YAML works fine without it.
      unwritten_history = @world.editor.history.to_a[@position..-1]
      if unwritten_history.any?
        contents = unwritten_history
          .each_with_object([]) { |line, arr| arr << line unless line == arr.last  }
          .map { |str| str.respond_to?(:without_ansi) ? str.without_ansi : str }
          .to_yaml
          .gsub(/^---.*?^/m, '')
        file.write contents
      end
    end
  end

  private

  def load_history
    debug_log "loading history file=#{file.inspect}"
    at_exit { save }

    if File.exists?(file) && File.readable?(file)
      history = YAML.load_file(file) || []

      # History starts at the end of the history loaded from file.
      @position = history.length

      # Rely on the builtin history for now.
      @world.editor.history.replace(history)
    end
  end
end
