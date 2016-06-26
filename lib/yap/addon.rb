require 'yap/addon/base'
require 'yap/addon/loader'
require 'yap/addon/path'
require 'yap/addon/reference'
require 'yap/addon/wrapper'

module Yap
  module Addon
    def self.load_rcfiles(files)
      Yap::Addon::Loader.load_rcfiles(files)
    end

    def self.load_directories(search_paths)
      Yap::Addon::Loader.load_directories(search_paths)
    end
  end
end
