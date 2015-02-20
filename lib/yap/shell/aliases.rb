require 'singleton'

module Yap::Shell
  class Aliases
    include Singleton

    def initialize
      @file = ENV["HOME"] + "/.yapaliases.yml"
      @aliases = begin
        YAML.load_file(@file)
      rescue
        {}
      end
    end

    def fetch_alias(name)
      @aliases[name]
    end

    def set_alias(name, command)
      @aliases[name] = command
      File.write @file, @aliases.to_yaml
    end

    def unset_alias(name)
      @aliases.delete(name)
    end

    def has_key?(key)
      @aliases.has_key?(key)
    end
  end
end
