require 'spec_helper'

describe 'Listing addons', type: :feature, repl: false do
  before do
    yap 'generate addon list'
  end

  it 'listing addons completes successfully' do
    expect { shell }.to have_exit_code(0)
  end
end
