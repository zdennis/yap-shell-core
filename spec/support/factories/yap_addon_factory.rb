require 'pathname'

class YapAddonFactory
  def self.create(**kwargs)
    new(**kwargs).create
  end

  attr_reader :dir, :contents, :name, :version

  def initialize(dir:, contents: {}, name:, version: '0.1.0')
    @dir = Pathname.new dir
    @contents = contents
    @contents[:initialize_world] ||= "# no-op"
    @name = name
    @version = version
  end

  def create
    FileUtils.mkdir_p lib_path.to_s
    File.write addon_rb_path, <<-RUBY.strip_heredoc
      |module #{full_name.split(/\W+/).map(&:capitalize).join}
      |  class Addon < ::Yap::Addon::Base
      |    self.export_as :'#{name}'
      |
      |    def initialize_world(world)
      |      #{contents[:initialize_world]}
      |    end
      |  end
      |end
    RUBY
  end

  private

  def addon_path
    @dir.join full_name_with_version
  end

  def full_name
    "yap-shell-addon-#{@name}"
  end

  def full_name_with_version
    "#{full_name}-#{@version}"
  end

  def lib_path
    addon_path.join 'lib'
  end

  def addon_rb_path
    lib_path.join "#{full_name}.rb"
  end

end
