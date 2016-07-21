require 'spec_helper'

describe 'Listing addons', type: :feature, repl: false do
  let!(:create_foo_addon) do
    YapAddonFactory.create \
      dir: addons_path,
      name: 'foo'
  end

  let!(:create_bar_addon) do
    YapAddonFactory.create \
      dir: addons_path,
      name: 'bar'
  end

  before do
    mkdir tmp_dir.join('.yap')
    write_file(
      tmp_dir.join('.yap/addons.yml'),
      {
        bar: { disabled: false },
        foo: { disabled: false }
      }.to_yaml
    )
  end

  it 'lists addons, and exits successfully' do
    yap "addon list"

    expect { output }.to have_printed_lines [
      "bar  enabled  (0.1.0)  \n",
      "foo  enabled  (0.1.0)  "
    ]
    expect { shell }.to have_exit_code(0)
  end

  it 'can list disabled addons only' do
    yap "addon disable foo"
    expect { output }.to have_printed_line 'Addon foo has been disabled'

    yap "addon list --disabled"
    expect { output }.to have_printed_line 'foo'
    expect { output }.to_not have_printed_line 'bar'
  end

  it 'can list enabled addons only' do
    yap "addon disable foo"
    expect { output }.to have_printed_line 'Addon foo has been disabled'

    yap "addon list --enabled"
    expect { output }.to have_printed_line 'bar'
    expect { output }.to_not have_printed_line 'foo'
  end
end
