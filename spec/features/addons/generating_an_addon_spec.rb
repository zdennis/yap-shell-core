require 'spec_helper'

describe 'Generating an addon', type: :feature, repl: false do
  let(:addons_path) { tmp_dir.join('addons/') }
  let(:yaprc_path) { tmp_dir.join('yaprc') }
  let(:yaprc_contents) { '' }

  let(:yap_cli_args) do
    [
      '--addon-paths', addons_path.to_s,
      '--rcfiles', yaprc_path.to_s,
      '--no-history',
      '--no-rcfiles',
      '--skip-first-time',
      'generate', 'addon', 'foo-bar'
    ]
  end

  before do
    set_yap_command_line_arguments yap_cli_args

    turn_on_debug_log(debug: 'editor')
    reinitialize_shell
  end

  it 'generates an addon in the current working directory' do
    # foo-addon is a shell function added by the foo-addon defined above;
    expect { output }.to have_printed_lines <<-TEXT.gsub(/^\s*\|/, '')
      |Creating addon foo-bar in yap-shell-addon-foo-bar/
      |
      |Create directory: yap-shell-addon-foo-bar done
      |Create directory: lib done
      |Creating file: Gemfile done
      |Creating file: yap-shell-addon-foo-bar.gemspec done
      |Creating file: LICENSE.txt done
      |Creating file: Rakefile done
      |Creating file: README.md done
      |Creating file: lib/yap-shell-addon-foo-bar.rb done
      |Create directory: lib/yap-shell-addon-foo-bar done
      |Creating file: lib/yap-shell-addon-foo-bar/version.rb done
      |
      |Yap addon generated! A few helpful things to note:
      |
      |  * The foo-bar addon has been generated in yap-shell-addon-foo-bar/
      |  * It is a standard rubygem, has its own gemspec, and is named yap-shell-addon-foo-bar
      |  * Yap loads the YapShellAddonFooBar, found in lib/yap-shell-addon-foo-bar.rb (start there)
      |  * Share your addon with others by building a gem and pushing it to rubygems
    TEXT
  end
end
