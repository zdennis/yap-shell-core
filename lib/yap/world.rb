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

    attr_accessor :last_result

    def self.instance(*args)
      @instance ||= new(*args)
    end

    def initialize(addons:)
      @env = ENV.to_h.dup
      dom = build_editor_dom

      @editor = RawLine::Editor.create(dom: dom)

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

    def aliases
      Yap::Shell::Aliases.instance
    end

    def builtins
      Yap::Shell::BuiltinCommand.builtins.keys.map(&:to_s)
    end

    def events
      @editor.events
    end

    def bind(key, &blk)
      @editor.bind(key) do
        blk.call self
      end
    end

    def unbind(key)
      @editor.unbind(key)
    end

    def func(name, &blk)
      Yap::Shell::ShellCommand.define_shell_function(name, &blk)
    end

    def shell(statement)
      context = Yap::Shell::Execution::Context.new(
        stdin:  $stdin,
        stdout: $stdout,
        stderr: $stderr
      )
      if statement.nil?
        @last_result = Yap::Shell::Execution::Result.new(
          status_code: 1,
          directory: Dir.pwd,
          n: 1,
          of: 1
        )
      else
        evaluation = Yap::Shell::Evaluation.new(stdin:$stdin, stdout:$stdout, stderr:$stderr, world:self)
        evaluation.evaluate(statement) do |command, stdin, stdout, stderr, wait|
          context.clear_commands
          context.add_command_to_run command, stdin:stdin, stdout:stdout, stderr:stderr, wait:wait
          @last_result = context.execute(world:self)
        end
      end

      @last_result
    end

    def foreground?
      Process.getpgrp == Termios.tcgetpgrp($stdout)
    end

    def history
      @editor.history
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

      RawLine::DomTree.new(
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
      ).tap do |dom|
        dom.prompt_box = @prompt_box
        dom.input_box = @input_box
        dom.content_box = @content_box
      end
    end
  end
end
