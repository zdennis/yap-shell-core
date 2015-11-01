require 'term/ansicolor'
require 'forwardable'

require 'rawline'
require 'yap/shell/execution'
require 'yap/shell/prompt'
require 'yap/world/addons'
require 'termios'

module Yap
  class World
    include Term::ANSIColor
    extend Forwardable

    DEFAULTS = {
      primary_prompt_text: "yap> ",
      secondary_prompt_text: "> "
    }

    attr_accessor :prompt, :secondary_prompt, :contents, :repl, :editor, :env
    attr_reader :addons

    def self.instance(*args)
      @instance ||= new(*args)
    end

    def initialize(addons:)
      @env = ENV.to_h.dup
      build_editor_dom

      @editor = RawLine::Editor.new do |editor|
        editor.dom = build_editor_dom
        editor.prompt_box = @prompt_box
        editor.input_box = @input_box
        editor.content_box = @content_box
        editor.word_break_characters = " \t\n\"\\'`@$><=;|&{()/"
      end

      self.prompt = Yap::Shell::Prompt.new(text: DEFAULTS[:primary_prompt_text])
      self.secondary_prompt = Yap::Shell::Prompt.new(text: DEFAULTS[:secondary_prompt_text])

      @repl = Yap::Shell::Repl.new(world:self)

      @addons = addons.reduce(Hash.new) do |hsh, addon|
        hsh[addon.addon_name] = addon
        hsh
      end

      # initialize after they are all loaded in case they reference each other.
      addons.each { |addon| addon.initialize_world(self) }
    end

    def [](addon_name)
      @addons.fetch(addon_name){ raise(ArgumentError, "No addon loaded registered as #{addon_name}") }
    end

    def events
      @editor.events
    end

    def func(name, &blk)
      Yap::Shell::ShellCommand.define_shell_function(name, &blk)
    end

    def foreground?
      Process.getpgrp == Termios.tcgetpgrp($stdout)
    end

    def interactive!
      refresh_prompt
      @editor.start
    end

    def prompt
      @prompt
    end

    def prompt=(prompt=nil, &blk)
      # TODO if prompt_controller then undefine, cancel events, etc
      if prompt.is_a?(Yap::Shell::Prompt)
        @prompt = prompt
      elsif prompt.respond_to?(:call) # proc
        @prompt = Yap::Shell::Prompt.new(text:prompt.call, &prompt)
      else # text
        @prompt = Yap::Shell::Prompt.new(text:prompt, &blk)
      end
    end

    def refresh_prompt
      @editor.prompt = @prompt.update.text
    end

    def right_prompt_text=(str)
      @right_status_float.width = str.length
      @right_status_box.content = str
    end

    def subscribe(*args, &blk)
      @editor.subscribe(*args, &blk)
    end

    def build_editor_dom
      @left_status_box = TerminalLayout::Box.new(content: "", style: {display: :inline})
      @right_status_box = TerminalLayout::Box.new(content: "", style: {display: :inline})
      @prompt_box = TerminalLayout::Box.new(content: "yap>", style: {display: :inline})
      @input_box = TerminalLayout::InputBox.new(content: "", style: {display: :inline})

      @content_box = TerminalLayout::Box.new(content: "", style: {display: :block})
      @bottom_left_status_box = TerminalLayout::Box.new(content: "", style: {display: :inline})
      @bottom_right_status_box = TerminalLayout::Box.new(content: "", style: {display: :inline})

      @right_status_float = TerminalLayout::Box.new(style: {display: :float, float: :right, width: @right_status_box.content.length},
        children: [
          @right_status_box
        ]
      )

      return TerminalLayout::Box.new(
        children:[
          @right_status_float,
          @left_status_box,
          @prompt_box,
          @input_box,
          @content_box,
          TerminalLayout::Box.new(style: {display: :float, float: :left, width: @bottom_left_status_box.content.length},
            children: [
              @bottom_left_status_box
            ]
          ),
          TerminalLayout::Box.new(style: {display: :float, float: :right, width: @bottom_right_status_box.content.length},
            children: [
              @bottom_right_status_box
            ]
          )
        ]
      )
    end
  end
end
