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
        "#{ENV['HOME']}/.yaprc"
      ]
    end

    def path_for(part)
      yap_path.join(part)
    end

    def yap_path
      Pathname.new "#{ENV['HOME']}/.yap"
    end
  end
end
