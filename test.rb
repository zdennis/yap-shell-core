require 'terminfo'
require 'io/console'
require 'term/ansicolor'

$z = File.open("/tmp/z.log", "w+")
$z.sync = true

module EventEmitter
  def _callbacks
    @_callbacks ||= Hash.new { |h, k| h[k] = [] }
  end

  def on(type, *args, &blk)
    _callbacks[type] << blk
    self
  end

  def emit(type, *args)
    _callbacks[type].each do |blk|
      blk.call(*args)
    end
  end
end

class TerminalRenderer
  def initialize(layout_manager)
    @output = $stdout
    @terminfo = TermInfo.new ENV["TERM"], @output
    @layout_manager = layout_manager
    @layout_manager.on(:laid_out_content) do |content|
      display(content)
    end
  end

  def display(content)
    @output.print(
      @terminfo.control_string("clear"),  # clear screen
      @terminfo.control_string("hpa", 0), # go to column 0 (assuming we're on row 0)
      @terminfo.control_string("sc"), # save cursor
      content,
      @terminfo.control_string("rc") # restore cursor
    )
  end
end

class LayoutManager
  include EventEmitter

  def initialize
    @renderers = []
    @mutex = Mutex.new
  end

  def add(renderer)
    @renderers << renderer
    renderer.on(:content_changed) do
      layout
    end
  end

  def layout(width:nil, height:nil)
    @mutex.synchronize { _layout(width, height) }
  end

  def _layout(width, height)
    width ||= $stdout.winsize.last
    height ||= $stdout.winsize.first
    results_arr = []
    column = 0
    row = 0
    @renderers.each do |renderer|
      $z.puts "", "rendering #{renderer.id}"
      $z.puts "Column: #{column} at row: #{row}"
      $z.puts "Term width: #{width} height: #{height}"
      $z.flush
      text = renderer.render(width)

      if renderer.anchor == :right
        start_column = width - text.length
        if start_column <= column || row > 0 # don't render the right prompt anywhere but the first line
          next # we've already rendered content here, so skip
        else
          column = start_column
        end
      end

      text.each_char do |ch|
        queued_text = results_arr.fetch(row){ " " * width }
        queued_text[column] = ch
        column += 1

        results_arr[row] = queued_text

        if queued_text.length > width
          row += 1
          column = 0
        end
      end

    end

    # puts "-"*40
    # puts results_arr.length
    # puts results_arr.inspect
    # puts results_arr#.join("\n")
    emit :laid_out_content, results_arr.join("\n")
    results_arr#.join("\n")
  end
end

class ContentRenderer
  include EventEmitter

  attr_reader :display, :anchor

  def id
    @content.id
  end

  def initialize(content, display:nil, anchor:nil)
    @display = display
    @anchor = anchor
    @last_width_rendered = nil
    @content = content
    @content.on(:content_changed) do |content, from:, to:|
      @dirty = true
      emit :content_changed
    end
  end

  def render(width)
    @content.text
    # @content.text.split(//).each_slice(width).map do |chars|
    #   chars.join
    # end
  end
end

class Content
  include EventEmitter

  attr_accessor :id, :text

  def initialize(id:, text:"")
    @id = id
    @text = text
  end

  def text=(str)
    old_str = @text
    @text = str
    emit :content_changed, self, from:old_str, to:@text
  end
end

anchor_left = Content.new id:"anchor-left", text:""
prompt = Content.new id:"prompt", text:"> "
input = Content.new id:"input"
right_prompt = Content.new id:"right-prompt"

anchor_left_renderer = ContentRenderer.new anchor_left
prompt_renderer = ContentRenderer.new(prompt, display: :inline)
input_renderer = ContentRenderer.new(input)
right_prompt_renderer = ContentRenderer.new(right_prompt, anchor: :right)

layout_manager = LayoutManager.new
layout_manager.add anchor_left_renderer
layout_manager.add prompt_renderer
layout_manager.add input_renderer
layout_manager.add right_prompt_renderer

terminal = TerminalRenderer.new(layout_manager)

prompt.text = "> "
sleep 1
input.text = "ls a b c d e f g h i j k l m"
# sleep 1
# prompt.text = "abcdefghijklmnopqrstuvwxyz1234567890abcdefghijklmnopqrstuvwxyz1234567890> "
# sleep 1
anchor_left.text = "£ "
sleep 1
prompt.text = "#{Dir.pwd}> "
sleep 1

Thread.new do
  loop do
    ["ls a b c", "echo hello world, goodbye world", "cat foo"].each do |str|
      input.text = str
      sleep 0.75
    end
  end
end

Thread.new do
  loop do
    %w(apples oranges bananas grapefruits pears cherries).each do |fruit|
      anchor_left.text = "(#{fruit}) "
      sleep 0.5
    end
  end
end

loop do
  right_prompt.text = "#{Time.now.to_s}"
  sleep 1
end
