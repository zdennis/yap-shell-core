require 'spec_helper'

describe 'Addons', type: :feature do
  let(:addons_path) { tmp_dir.join('addons/') }
  let(:yaprc_path) { tmp_dir.join('yaprc') }
  let(:yaprc_contents) { '' }

  let(:foo_addon_path) { addons_path.join('yap-shell-foo-addon-0.1.0') }
  let(:foo_lib_addon_path) { foo_addon_path.join('lib') }
  let(:foo_addon_rb_path) { foo_lib_addon_path.join('yap-shell-foo-addon.rb') }
  let(:create_foo_addon) do
    mkdir_p foo_lib_addon_path.to_s
    write_file foo_addon_rb_path.to_s, <<-RUBY.strip_heredoc
      |module YapShellFooAddon
      |  class Addon < ::Yap::World::Addon
      |    self.export_as :foo
      |
      |    def initialize_world(world)
      |      world.func('foo-addon') do |args:, stdout:|
      |        stdout.puts \"You passed \#\{args.inspect\} to foo-addon\"
      |      end
      |    end
      |  end
      |end
    RUBY
  end

  let(:bar_addon_path) { addons_path.join('yap-shell-bar-addon-0.1.0') }
  let(:bar_lib_addon_path) { bar_addon_path.join('lib') }
  let(:bar_addon_rb_path) { bar_lib_addon_path.join('yap-shell-bar-addon.rb') }
  let(:create_bar_addon) do
    mkdir_p bar_lib_addon_path.to_s
    write_file bar_addon_rb_path.to_s, <<-RUBY.strip_heredoc
      |module YapShellBarAddon
      |  class Addon < ::Yap::World::Addon
      |    self.export_as :bar
      |
      |    def initialize_world(world)
      |      world.func('bar-addon') do |args:, stdout:|
      |        stdout.puts \"You passed \#\{args.inspect\} to bar-addon\"
      |      end
      |    end
      |  end
      |end
    RUBY
  end

  let(:create_yaprc_file) do
    write_file yaprc_path.to_s, <<-RUBY.strip_heredoc
      |#{yaprc_contents}
    RUBY
  end

  let(:yap_cli_args) do
    [
      '--addon-paths', addons_path.to_s,
      '--rcfiles', yaprc_path.to_s,
      '--no-history',
      '--no-rcfiles',
      '--skip-first-time'
    ]
  end

  before do
    set_yap_command_line_arguments yap_cli_args

    create_foo_addon
    create_bar_addon
    create_yaprc_file

    turn_on_debug_log(debug: 'editor')
    reinitialize_shell
  end

  it 'loads addons it finds in addon paths' do
    # foo-addon is a shell function added by the foo-addon defined above
    type 'foo-addon hello world'
    enter
    expect { output }.to have_printed("You passed [\"hello\", \"world\"] to foo-addon")
  end

  it 'makes addons available thru its export_as name' do
    type '!addons.keys.include?(:foo)'
    enter
    expect { output }.to have_printed('true')
    clear_all_output

    type '!addons.keys.include?(:non_existent_addon)'
    enter
    expect { output }.to have_printed('false')
  end

  describe 'disabling an addon', repl: false do
    let(:yap_cli_args) do
      [
        '--addon-paths', addons_path.to_s,
        'addon', 'disable', 'foo'
      ]
    end

    it 'writes to disk that the addon has been disabled' do
      expect { output }.to have_printed("Addon foo has been disabled")

      expect(File.exists?(tmp_dir.join('.yap/addons.yml'))).to be(true)

      addons_config_hsh = YAML.load_file(tmp_dir.join('.yap/addons.yml'))
      expect(addons_config_hsh[:foo]).to include(disabled: true)
    end
  end

  describe 'enabling an addon', repl: false do
    let(:yap_cli_args) do
      [
        '--addon-paths', addons_path.to_s,
        'addon', 'enable', 'foo'
      ]
    end

    it 'writes to disk that the addon has been enabled' do
      expect { output }.to have_printed("Addon foo has been enabled")

      expect(File.exists?(tmp_dir.join('.yap/addons.yml'))).to be(true)

      addons_config_hsh = YAML.load_file(tmp_dir.join('.yap/addons.yml'))
      expect(addons_config_hsh[:foo]).to include(disabled: false)
    end
  end

  describe 'listing addons', repl: false do
    let(:yap_cli_args) do
      [
        '--addon-paths', addons_path.to_s,
        'addon', 'list'
      ]
    end

    before do
      mkdir tmp_dir.join('.yap')
      write_file(
        tmp_dir.join('.yap/addons.yml'),
        {
          bar: { disabled: true },
          foo: { disabled: false }
        }.to_yaml
      )
      reinitialize_shell
      clear_all_output
    end

    it 'lists all addons found in the addon-paths' do
      expect { output }.to have_printed(/bar.*foo/m)
    end

    describe 'enabled' do
      let(:yap_cli_args) do
        [
          '--addon-paths', addons_path.to_s,
          'addon', 'list', '--enabled'
        ]
      end

      it 'lists enabled addons' do
        expect { output }.to have_printed(/foo/m)
        expect { output }.to have_not_printed(/bar/m)
      end
    end

    describe 'disabled' do
      let(:yap_cli_args) do
        [
          '--addon-paths', addons_path.to_s,
          'addon', 'list', '--disabled'
        ]
      end

      it 'lists disabled addons' do
        expect { output }.to have_printed(/bar/m)
        expect { output }.to have_not_printed(/foo/m)
      end
    end
  end
end
