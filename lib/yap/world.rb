require 'term/ansicolor'
require 'forwardable'
require 'yap/shell/execution'
require 'yap/shell/prompt'
require 'yap/world/addons'
require 'termios'

module Yap
  class World
    include Term::ANSIColor
    extend Forwardable

    attr_accessor :prompt, :contents, :addons

    def initialize(options)
      (options || {}).each do |k,v|
        self.send "#{k}=", v
      end

      addons.each do |addon|
        addon.initialize_world(self)
      end
    end

    def func(name, &blk)
      Yap::Shell::ShellCommand.define_shell_function(name, &blk)
    end

    def readline
      ::Readline
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

    (String.instance_methods - Object.instance_methods).each do |m|
      next if [:object_id, :__send__, :initialize].include?(m)
      def_delegator :@contents, m
    end

  end
end
