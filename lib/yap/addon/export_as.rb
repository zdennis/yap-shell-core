module Yap
  module Addon
    module ExportAs
      def self.find_in_file(path)
        export_as = File.read(path).
          scan(/export_as\(?\s*:?(['"]?)(.*)\1/).
          flatten.
          last
      end
    end
  end
end
