require 'yap/addon/base'
require 'yap/addon/export_as'
require 'yap/addon/loader'
require 'yap/addon/path'
require 'yap/addon/rc_file'
require 'yap/addon/reference'

module Yap
  module Addon
    def self.load_rcfiles(files)
      Yap::Addon::Loader.load_rcfiles(files)
    end

    def self.load_for_configuration(configuration)
      addon_references = Yap::Addon::Path.find_for_configuration(configuration)
      Yap::Addon::Loader.new(addon_references).load_all
    end

    def self.export_as_for_gemspec(gemspec)
      addonrb_path = File.join('lib', gemspec.name + '.rb')
      ExportAs.find_in_file(addonrb_path)
    end
  end
end
