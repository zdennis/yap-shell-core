require 'yap/world'

module Yap
  def self.configuration
    @configuration ||= Configuration.new
  end

  class Configuration
    attr_accessor :addon_paths
    attr_accessor :rcfiles

    def initialize
      @addon_paths = [
        Dir["#{File.dirname(__FILE__)}/../../addons/*"],
        Dir["#{ENV['HOME']}/.yap/addons/*"]
      ].flatten

      @rcfiles = [
        Dir["#{ENV['HOME']}/.yaprc"]
      ].flatten
    end
  end
end
