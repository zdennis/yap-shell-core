require 'term/ansicolor'
require 'forwardable'
require 'yap/shell/execution'
require 'termios'

module Yap
  class Prompt
    attr_reader :text

    def initialize(text=nil, &blk)
      @text = text
      @blk = blk
    end

    def update
      if @blk
        @text = @blk.call
      end
      self
    end
  end

  class World
    include Term::ANSIColor
    extend Forwardable

    attr_accessor :current_prompt, :prompt, :contents, :addons

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
      if prompt.is_a?(Prompt)
        @prompt = prompt
      elsif prompt.respond_to?(:call)
        @prompt = Prompt.new(&prompt)
      else
        @prompt = Prompt.new(prompt, &blk)
      end
    end

    (String.instance_methods - Object.instance_methods).each do |m|
      next if [:object_id, :__send__, :initialize].include?(m)
      def_delegator :@contents, m
    end

  end
end
