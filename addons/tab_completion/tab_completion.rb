require 'term/ansicolor'

class TabCompletion < Addon
  require 'tab_completion/completer'
  require 'tab_completion/dsl_methods'
  require 'tab_completion/custom_completion'
  require 'tab_completion/file_completion'

  class CompletionResult
    attr_accessor :text, :type, :descriptive_text

    def initialize(text:, type:, descriptive_text: nil)
      @descriptive_text = descriptive_text || text
      @text = text
      @type = type
    end

    def ==(other)
      other.is_a?(self.class) && @text == other.text && @type == other.type
    end

    def <=>(other)
      @text <=> other.text
    end

    def to_s
      @text
    end
  end

  COMPLETIONS = [ FileCompletion ]

  Color = Term::ANSIColor

  DISPLAY_PROCS = Hash.new{ |h,k| h[k] = ->(text){ text } }.merge(
    directory: -> (text){ text + "/" }
  )

  STYLE_PROCS = Hash.new{ |h,k| h[k] = ->(text){ text } }.merge(
    directory: -> (text){ Color.bold(Color.red(text)) },
    command:   -> (text){ Color.bold(Color.green(text)) },
    symlink:   -> (text){ Color.bold(Color.cyan(text)) },
    selected:  -> (text){ Color.negative(text) }
  )

  DECORATION_PROCS = Hash.new{ |h,k| h[k] = ->(text){ text } }.merge(
    directory: -> (text){ text + "/" },
    command:   -> (text){ text + "@" }
  )

  attr_reader :editor, :world

  def initialize_world(world)
    @world = world
    @world.extend TabCompletion::DslMethods
    @editor = @world.editor
    @editor.completion_proc = -> (word, line){
      complete(word, line)
    }
    @editor.bind(:tab){ @editor.complete }
    @completions = COMPLETIONS.dup

    @style_procs = STYLE_PROCS.dup
    @decoration_procs = DECORATION_PROCS.dup
    @display_procs = DISPLAY_PROCS.dup

    editor.on_word_complete do |event|
      sub_word = event[:payload][:sub_word]
      word = event[:payload][:word]
      actual_completion = event[:payload][:completion]
      possible_completions = event[:payload][:possible_completions]

      str = possible_completions.map.with_index do |completion, i|
        if completion == actual_completion
          style_text_for_selected_match(completion)
        else
          style_text_for_nonselected_match(completion)
        end
      end.join("  ")

      editor.content_box.content = str
    end

    editor.on_word_complete_no_match do |event|
      sub_word = event[:payload][:sub_word]
      word = event[:payload][:word]
      # editor.content_box.content = "Failed to find a match to complete #{sub_word} portion of #{word}"
    end

    editor.on_word_complete_done do |event|
      editor.content_box.content = ""
    end
  end

  def add_completion(name, pattern, &blk)
    raise ArgumentError, "Must supply block!" unless block_given?
    # @completions.push CustomCompletion.new(name:name, pattern:pattern, world:world, &blk)
  end

  def set_decoration(type, &blk)
    raise ArgumentError, "Must supply block!" unless block_given?
    @style_procs[type] = blk
  end

  def complete(word, line)
    matches = @completions.sort_by(&:priority).reverse.map do |completion|
      if completion.respond_to?(:call)
        completion.call
      else
        completions = completion.new(
          world: @world,
          word_break_characters: editor.word_break_characters
        ).completions_for(word, line)
        completions.each do |completion|
          completion.text = display_text_for_match(completion)
        end
      end
    end.flatten

    matches
  end

  private

  def display_text_for_match(match)
    @display_procs[match.type].call(match.text.dup)
  end

  def style_text_for_selected_match(match)
    styled_text = @style_procs[match.type].call(match.descriptive_text.dup).to_s
    styled_text = @decoration_procs[match.type].call(styled_text).to_s
    uncolored_text = Color.uncolored(styled_text)
    @style_procs[:selected].call(uncolored_text).to_s
  end

  def style_text_for_nonselected_match(match)
    @decoration_procs[match.type].call(
      @style_procs[match.type].call(match.descriptive_text.dup).to_s
    )
  end

end
