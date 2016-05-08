require 'singleton'

module Yap::Shell
  class Aliases
    include Singleton

    def initialize
      @file = ENV["HOME"] + "/.yapaliases.yml"
      @aliases = begin
        Treefell['shell'].puts "reading aliases from disk: #{@file}"
        YAML.load_file(@file)
      rescue
        {}
      end
    end

    def names
      @aliases.keys
    end

    def fetch_alias(name)
      @aliases[name].tap do |contents|
        Treefell['shell'].puts "alias fetched name=#{name} contents=#{contents.inspect}"
      end
    end

    def set_alias(name, contents)
      @aliases[name] = contents
      Treefell['shell'].puts "alias set name=#{name} to #{contents.inspect}"
      write_to_disk
    end

    def unset_alias(name)
      @aliases.delete(name)
      Treefell['shell'].puts "alias unset name=#{name}"
      write_to_disk
    end

    def has_key?(key)
      @aliases.has_key?(key)
    end

    def to_h
      @aliases.keys.compact.sort.inject(Hash.new) do |h,k|
        h[k] = @aliases[k]
        h
      end
    end

    private

    def write_to_disk
      File.write(@file, @aliases.to_yaml).tap do
        Treefell['shell'].puts "aliases written to disk: #{@file}"
      end
    end
  end
end
