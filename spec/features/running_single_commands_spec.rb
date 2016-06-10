require 'spec_helper'

describe 'Running single commands' do
  before(:all) do
    set_yap_command_line_arguments \
      '--no-history', '--no-addons', '--no-rcfiles', '--skip-first-time'

    turn_on_debug_log(debug: 'editor')

    initialize_shell

    mkdir tmp_dir
    Dir.chdir tmp_dir

    type "cd #{tmp_dir}"
    enter

    type "pwd"
    enter
    expect { output }.to have_printed(File.expand_path(tmp_dir))
  end

  after(:each) do
    Dir.chdir(tmp_dir) do
      FileUtils.rm_rf Dir.glob('*')
    end
  end

  describe 'fileystem commands' do
    it 'runs basic filesystem commands' do
      touch 'bar.txt'
      type 'ls .'
      enter

      expect { output }.to have_printed("bar.txt")

      type 'echo "hello there"'
      enter
      expect { output }.to have_printed("hello there\n")
    end
  end

  describe 'piping commands' do
    it 'pipes filesystem commands' do
      type "echo 'food' | sed -e 's/o/_/g'"
      enter
      expect { output }.to have_printed(/^f__d\n/m)
    end
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

      type "echo $?"
      enter
      expect { output }.to have_printed(/0/m)
    end

    it 'can combine logical AND and OR' do
      type "(echo foo && non-existent-command) || echo bar"
      enter
      expect { error_output }.to have_printed(/yap: command not found: non-existent-command/m)
      expect { output }.to have_printed(/foo.*\n.*bar/m)

      type "(echo foo || non-existent-command) && echo bar"
      enter
      expect { error_output }.to have_printed(/yap: command not found: non-existent-command/m)
      expect { output }.to have_printed(/foo.*\n.*bar/m)

      type "(non-existent-command && echo foo) && echo bar"
      enter
      expect { error_output }.to have_printed(/yap: command not found: non-existent-command/m)
      expect { output }.to_not have_printed(/foo.*\n.*bar/m)
    end
  end

  describe 'aliases' do
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
      expect { output }.to have_printed(/bar\n/)
    end

    it 'unsets them' do
      type 'unalias foo'
      enter
      expect { output }.to have_printed(/Removing alias foo done\n/)

      type 'alias | grep foo'
      enter
      expect(output).to_not match(/alias foo='echo bar'/)
    end
  end
end
