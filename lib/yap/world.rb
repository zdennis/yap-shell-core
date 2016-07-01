require 'term/ansicolor'
require 'fileutils'
require 'forwardable'
require 'rawline'
require 'termios'

module Yap
  require 'yap/addon'
  require 'yap/shell/execution'
  require 'yap/shell/prompt'

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

      # ensure yap directory exists
      if !File.exists?(configuration.yap_path)
        if configuration.skip_first_time?
          # skipping first time
        else
          puts
          puts yellow("Yap directory not found: #{configuration.yap_path}")
          puts
          puts "Initializing yap for the first time:"
          puts

          print "    Creating #{configuration.yap_path} "
          FileUtils.mkdir_p configuration.yap_path
          puts green("done")

          print "    Creating default #{configuration.preferred_yaprc_path} "
          FileUtils.cp configuration.yaprc_template_path, configuration.yap_path
          puts green("done")
          puts
          puts "To tweak yap take a look at #{configuration.preferred_yaprc_path}."
          puts
          puts "Reloading shell"
          reload!
        end
      end

      @editor = RawLine::Editor.create(dom: dom)

      self.prompt = Yap::Shell::Prompt.new(text: DEFAULTS[:primary_prompt_text])
      self.secondary_prompt = Yap::Shell::Prompt.new(text: DEFAULTS[:secondary_prompt_text])

      @repl = Yap::Shell::Repl.new(world:self)

      @addons_initialized = []
      @addons = AddonHash.new(
        self
      )

      addons.each do |addon|
        if addon.yap_enabled?
          @addons[addon.export_as] = addon
        end
      end

      @addons.values.select(&:yap_enabled?).each do |addon|
        initialize_addon(addon) unless addon_initialized?(addon)
        addon
      end
    end

    def addon_initialized?(addon)
      (@addons_initialized ||= []).include?(addon)
    end

    def initialize_addon(addon)
      return unless addon
      begin
        addon.initialize_world(self)
        (@addons_initialized ||= []) << addon
      rescue Exception => ex
        puts Term::ANSIColor.red(("The #{addon.addon_name} addon failed to initialize due to error:"))
        puts ex.message
        puts ex.backtrace[0..5]
      end
    end

    class AddonHash < Hash
      def initialize(world)
        @world = world
      end

      def [](key)
        addon = super
        unless @world.addon_initialized?(addon)
          @world.initialize_addon(addon)
        end
        addon
      end
    end

    def configuration
      ::Yap.configuration
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

    def shell_commands
      Yap::Shell::ShellCommand.registered_functions.keys.map(&:to_s)
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

    def reload!
      exec configuration.yap_binpath
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
          @last_result = context.execute(world:self) || 0
          if @last_result.is_a?(Integer)
            Yap::Shell::Execution::Result.new(
              status_code: @last_result,
              directory: Dir.pwd,
              n: 1,
              of: 1
            )
          else
            @last_result
          end
        end
      end

      @last_result
    end

    def foreground?
      return unless STDIN.isatty
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
      if prompt.is_a?(Yap::Shell::Prompt)
        @prompt = prompt
      elsif prompt.respond_to?(:call) # proc
        @prompt = Yap::Shell::Prompt.new(text:prompt.call, &prompt)
      else # text
        @prompt = Yap::Shell::Prompt.new(text:prompt, &blk)
      end
    end

    def secondary_prompt=(prompt=nil, &blk)
      if prompt.is_a?(Yap::Shell::Prompt)
        @secondary_prompt = prompt
      elsif prompt.respond_to?(:call) # proc
        @secondary_prompt = Yap::Shell::Prompt.new(text:prompt.call, &prompt)
      else # text
        @secondary_prompt = Yap::Shell::Prompt.new(text:prompt, &blk)
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
        @prompt_box.name = "prompt-box"
        @input_box.name = "input-box"
        @content_box.name = "content-box"
      end
    end
  end
end
