module Yap
  autoload :Shell, "yap/shell"
  autoload :World, "yap/world"

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

        # Module.new.tap { |m| m.module_eval IO.read(file) }
        IO.read(file)
      end
    end
  end


  def self.run_shell
    addons = WorldAddons.load_from_files(files: [
      "#{ENV['HOME']}/.yaprc"
    ])
    Shell::Impl.new(addons: addons).repl
  end
end
