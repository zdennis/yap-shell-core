require 'pathname'

module Yap
  require 'yap/world'

  def self.configuration
    @configuration ||= Configuration.new
  end

  class Configuration
    attr_accessor :addon_paths
    attr_accessor :rcfiles

    def self.option(name, type=nil)
      reader_method = name.to_s
      define_method(reader_method) do
        value = instance_variable_get("@#{name}")
        return !!value if type == :boolean
        value
      end

      writer_method = "#{reader_method}="
      define_method(writer_method) do |value|
        instance_variable_set("@#{name}", value)
      end

      if type == :boolean
        query_method = "#{reader_method}?"
        alias_method query_method, reader_method
      end
    end

    option :use_addons, :boolean
    option :use_history, :boolean
    option :use_rcfiles, :boolean

    def initialize
      @addon_paths = [
        "#{File.dirname(__FILE__)}/../../addons",
        "#{ENV['HOME']}/.yap/addons"
      ]

      @rcfiles = [
        "#{ENV['HOME']}/.yaprc",
        preferred_yaprc_path
      ]
    end

    def path_for(part)
      yap_path.join(part)
    end

    def preferred_yaprc_path
      yap_path.join("yaprc")
    end

    def yaprc_template_path
      Pathname.new(File.dirname(__FILE__)).join('../../rcfiles/yaprc')
    end

    def yap_path
      Pathname.new "#{ENV['HOME']}/.yap"
    end
  end
end
