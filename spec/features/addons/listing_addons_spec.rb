require 'spec_helper'

describe 'Listing addons', type: :feature, repl: false do
  let(:addons_path) { tmp_dir.join('addons/') }
  let(:yaprc_path) { tmp_dir.join('yaprc') }
  let(:yaprc_contents) { '' }

  let(:yap_cli_args) do
    [
      'addon', 'list'
    ]
  end

  before do
    set_yap_command_line_arguments yap_cli_args
    reinitialize_shell
  end

  it 'listing addons completes successfully' do
    expect { shell }.to have_exit_code(0)
  end
end
