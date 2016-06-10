require 'spec_helper'

describe 'Filesystem commands', type: :feature do
  it 'runs filesystem commands' do
    touch 'bar.txt'
    type 'ls .'
    enter

    expect { output }.to have_printed("bar.txt")

    type 'echo "hello there"'
    enter
    expect { output }.to have_printed("hello there\n")
    clear_all_output
  end

  it 'pipes filesystem commands' do
    type "echo 'food' | sed -e 's/o/_/g'"
    enter
    expect { output }.to have_printed(/^f__d\n/m)
  end

  describe 'conditionals' do
    it 'supports logical AND: &&' do
      type "echo foo && echo bar"
      enter
      expect { output }.to have_printed(/foo.*\n.*bar/m)
    end

    it 'supports logical OR: &&' do
      type "non-existent-command || echo bar"
      enter
      expect { error_output }.to have_printed(/yap: command not found: non-existent-command/m)
      expect { output }.to have_printed(/bar/m)
      clear_all_output

      type "echo $?"
      enter
      expect { output }.to have_printed(/0/m)
    end

    it 'can combine logical AND and OR' do
      type "(echo foo && non-existent-command) || echo bar"
      enter
      expect { error_output }.to have_printed(/yap: command not found: non-existent-command/m)
      expect { output }.to have_printed(/foo.*\n.*bar/m)
      clear_all_output

      type "(echo foo || non-existent-command) && echo bar"
      enter
      expect { error_output }.to_not have_printed(/yap: command not found: non-existent-command/m)
      expect { output }.to have_printed(/foo.*\n.*bar/m)
      clear_all_output

      type "(non-existent-command && echo foo) && echo bar"
      enter
      expect { error_output }.to have_printed(/yap: command not found: non-existent-command/m)
      expect { output }.to_not have_printed(/foo.*\n.*bar/m)
    end
  end
end
