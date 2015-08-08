require 'term/ansicolor'
require 'forwardable'

require 'yap/shell/repl/rawline'
require 'yap/shell/execution'
require 'yap/shell/prompt'
require 'yap/world/addons'
require 'termios'

module Yap
  class World
    include Term::ANSIColor
    extend Forwardable

    attr_accessor :prompt, :contents, :repl, :editor, :env
    attr_reader :addons

    def self.instance(*args)
      @instance ||= new(*args)
    end

    def initialize(addons:)
      @env = ENV.to_h.dup

      @editor = RawLine::Editor.new do |editor|
        editor.word_break_characters = " \t\n\"\\'`@$><=;|&{()/"
      end

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

    def func(name, &blk)
      Yap::Shell::ShellCommand.define_shell_function(name, &blk)
    end

    def foreground?
      Process.getpgrp == Termios.tcgetpgrp($stdout)
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
      @prompt_controller = Yap::Shell::PromptController.new(world:self, prompt:@prompt)
    end
  end
end
