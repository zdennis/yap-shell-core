require 'term/ansicolor'

module Yap
  module Cli
    module Commands
      class Addon::Uninstall < Base
        def initialize(addon_name)
          @addon_name = addon_name
        end

        def process
          output = `gem uninstall -a yap-shell-addon-#{@addon_name}`
          if $?.exitstatus == 0
            puts Colors.green("#{@addon_name} was uninstalled succesfully.")
            puts "Don't forget to run #{Colors.yellow('reload!')} to start a session with the addon."
          else
            puts Colors.red("#{@addon_name} failed to uninstall:")
            puts output
          end
        end
      end
    end
  end
end
