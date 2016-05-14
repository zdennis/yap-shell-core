require 'pathname'

module Yap
  require 'yap/world'

  def self.configuration
    @configuration ||= Configuration.new
  end

  class Configuration
    attr_accessor :addon_paths
    attr_accessor :rcfiles

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
