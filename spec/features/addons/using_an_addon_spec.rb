require 'spec_helper'

describe 'Using an addon', type: :feature do
  let(:yaprc_path) { tmp_dir.join('yaprc') }
  let(:yaprc_contents) { '' }

  let(:create_foo_addon) do
    YapAddonFactory.create(
      dir: addons_path,
      name: 'foo',
      version: '0.1.0',
      contents: {
        initialize_world: <<-RUBY.strip_heredoc
          |world.func('foo-addon') do |args:, stdout:|
          |  stdout.puts \"You passed \#\{args.inspect\} to foo-addon\"
          |end
        RUBY
      }
    )
  end

  let(:create_bar_addon) do
    YapAddonFactory.create(
      dir: addons_path,
      name: 'bar',
      version: '0.1.0',
      contents: {
        initialize_world: <<-RUBY.strip_heredoc
          |world.func('bar-addon') do |args:, stdout:|
          |  stdout.puts \"You passed \#\{args.inspect\} to bar-addon\"
          |end
        RUBY
      }
    )
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
end
