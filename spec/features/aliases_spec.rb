require 'spec_helper'

describe 'Aliases', type: :feature do
  before do
    type "alias foo='echo bar'"
    enter
    expect { output }.to have_printed(/Setting alias foo done/)
  end

  it 'sets them' do
    type 'alias | grep foo'
    enter
    expect { output }.to have_printed(/alias foo='echo bar'/)
  end

  it 'executes them' do
    type 'foo'
    enter
    expect { output }.to have_printed(/^bar$/m)
  end

  it 'unsets them' do
    type 'unalias foo'
    enter
    expect { output }.to have_printed(/Removing alias foo done\n/)

    type 'alias | grep foo'
    enter
    expect(output).to_not match(/alias foo='echo bar'/)
  end

  describe 'conditionals' do
    before do
      type "alias fail='non-existent-command'"
      enter
      type "alias pass='echo pass'"
      enter
      clear_all_output
    end

    it 'supports logical AND: &&' do
      type "pass && pass"
      enter
      expect { output }.to have_printed(/^pass$.*^pass$/m)
    end

    it 'supports logical OR: &&' do
      type "fail || pass"
      enter
      expect { error_output }.to have_printed(/yap: command not found: non-existent-command/m)
      expect { output }.to have_printed(/^pass$/m)
      clear_all_output

      type "echo $?"
      enter
      expect { output }.to have_printed(/0/m)
    end

    it 'can combine logical AND and OR' do
      type "(pass && fail) || pass"
      enter
      expect { error_output }.to have_printed(/yap: command not found: non-existent-command/m)
      expect { output }.to have_printed(/^pass$.*^pass$/m)
      clear_all_output

      type "(pass || fail) && pass"
      enter
      expect { error_output }.to have_not_printed(/yap: command not found: non-existent-command/m)
      expect { output }.to have_printed(/^pass$.*^pass$/m)
      clear_all_output

      type "(fail && pass) && pass"
      enter
      expect { error_output }.to have_printed(/yap: command not found: non-existent-command/m)
      expect { output }.to have_not_printed(/^pass$.*^pass$/m)
    end
  end
end
