require 'spec_helper'

describe 'Running Yap for the first time', type: :feature do
  before do
    # do not pass in --skip-first-time
    set_yap_command_line_arguments \
      '--no-history', '--no-addons', '--no-rcfiles'

    turn_on_debug_log(debug: 'editor')
    reinitialize_shell
  end

  it 'tells the user it has been initialized' do
    home_dir = tmp_dir.to_s
    message = <<-EOT.gsub(/^\s*\|/, '').chomp
      |Yap directory not found: #{home_dir}/.yap
      |
      |Initializing yap for the first time:
      |
      |    Creating #{home_dir}/.yap done
      |    Creating default #{home_dir}/.yap/yaprc done
      |
      |To tweak yap take a look at #{home_dir}/.yap/yaprc.
      |
      |Reloading shell
    EOT
    expect { output }.to have_printed(message)
  end

  it 'creates a $HOME/.yap/ directory for yap things to go' do
    expect { output }.to have_printed('Reloading shell')

    dot_yap_dir = tmp_dir.join('.yap').to_s
    expect(Dir.exist?(dot_yap_dir)).to be(true)
  end

  it 'creates a default .yap/yaprc rcfile' do
    expect { output }.to have_printed('Reloading shell')

    yaprc = tmp_dir.join('.yap/yaprc').to_s
    templaterc = yap_dir.join('rcfiles/yaprc')
    expect(File.exist?(yaprc)).to be(true)
    expect(IO.read(yaprc)).to eq(IO.read(templaterc))
  end
end
