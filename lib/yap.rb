require 'yap/shell'
require 'yap/world'

module Yap
  module WorldAddons
    def self.syntax_ok?(file)
      `ruby -c #{file}`
      $?.exitstatus == 0
    end

    def self.load_from_files(files:[])
      files.map do |file|
        (puts "Cannot load world addon: #{file} does not exist" and next) unless File.exist?(file)
        (puts "Cannot load world addon: #{file} is not readable" and next) unless File.exist?(file)
        (puts "Cannot load world addon: #{file} is a directory file" and next) if File.directory?(file)

        addon = file.end_with?("rc") ? load_rcfile(file) : load_addon_file(file)
        addon.load
      end
    end

    class RcFile
      def initialize(contents)
        @contents = contents
      end

      def load
        self
      end

      def initialize_world(world)
        world.instance_eval @contents
      end
    end

    def self.load_rcfile(file)
      RcFile.new IO.read(file)
    end

    def self.load_addon_file(file)
      name = File.basename(file).sub(/\.[^\.]+$/, "").capitalize
      klass_name = "Yap::WorldAddons::#{name}"

      load file

      if Yap::WorldAddons.const_defined?(name)
        Yap::WorldAddons.const_get(name)
      else
        raise("Did not find #{klass_name} in #{file}")
      end
    end
  end

  def self.run_shell
    addon_files = Dir[
      "#{ENV['HOME']}/.yaprc",
      "#{ENV['HOME']}/.yap-addons/*.rb"
    ]

    addons = WorldAddons.load_from_files(files:addon_files)
    Shell::Impl.new(addons: addons).repl
  end
end
