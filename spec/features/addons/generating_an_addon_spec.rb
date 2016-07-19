require 'spec_helper'

describe 'Generating an addon', type: :feature, repl: false do
  before do
    yap 'generate addon foo-bar'
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
      |Creating file: .gitignore done
      |git init . && git add . && git commit -m 'initial commit of foo-bar' done
      |
      |Yap addon generated! A few helpful things to note:
      |
      |  * The foo-bar addon has been generated in yap-shell-addon-foo-bar/
      |  * It is a standard rubygem, has its own gemspec, and is named yap-shell-addon-foo-bar
      |  * Yap loads the YapShellAddonFooBar, found in lib/yap-shell-addon-foo-bar.rb (start there)
      |  * Share your addon with others by building a gem and pushing it to rubygems

      |For more information see https://github.com/zdennis/yap-shell/wiki/Addons
      |
      |Now, to get started:
      |
      |   cd yap-shell-addon-foo-bar
    TEXT
  end
end
