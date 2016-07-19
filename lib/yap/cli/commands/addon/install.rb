require 'term/ansicolor'

module Yap
  module Cli
    module Commands
      class Addon::Install < Base
        include Term::ANSIColor

        def initialize(addon_name)
          @addon_name = addon_name
        end

        def process
          output = `gem install yap-shell-addon-#{@addon_name}`
          if $?.exitstatus == 0
            puts Colors.green("#{@addon_name} was installed successfully.")
            puts "Don't forget to run #{Colors.yellow('reload!')} to load the addon."
          else
            puts Colors.red("#{@addon_name} failed to install:")
            puts output
          end
        end
      end
    end
  end
end
