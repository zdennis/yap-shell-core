puts ENV["PATH"]
$stdout.flush

require 'term/ansicolor'
require 'forwardable'
require 'yap/shell/execution'

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

    def prompt
      if @prompt.respond_to? :call
        @prompt.call
      else
        @prompt
      end
    end

    (String.instance_methods - Object.instance_methods).each do |m|
      next if [:object_id, :__send__, :initialize].include?(m)
      def_delegator :@contents, m
    end

  end
end
