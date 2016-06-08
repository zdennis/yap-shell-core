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
    very_soon { expect(output).to include(File.expand_path(tmp_dir)) }
  end

  after(:all) do
    FileUtils.rm_rf "#{tmp_dir}/*"
  end

  describe 'fileystem commands' do
    it 'runs basic filesystem commands' do
      touch 'foo.txt'
      touch 'bar.txt'
      type 'ls .'
      enter

      very_soon do
        expect(output).to match(/bar.txt\nfoo.txt\n/m)
      end

      type 'echo "hello there"'
      enter

      very_soon do
        expect(output).to match(/hello there\n/m)
      end
    end
  end

  describe 'piping commands' do
    it 'pipes filesystem commands' do
      type "echo 'food' | sed -e 's/o/_/g'"
      enter

      very_soon do
        expect(output).to match(/^f__d\n/m)
      end
    end
  end

  describe 'aliases' do
    before do
      type "alias foo='echo bar'"
      enter
      very_soon do
        expect(output).to match(/Setting alias foo done/)
      end
    end

    it 'sets them' do
      type 'alias | grep foo'
      enter
      very_soon do
        expect(output).to match(/alias foo='echo bar'/)
      end
    end

    it 'executes them' do
      type 'foo'
      enter
      very_soon do
        expect(output).to match(/bar\n/)
      end
    end

    it 'unsets them' do
      type 'unalias foo'
      enter
      very_soon do
        expect(output).to match(/Removing alias foo done\n/)
      end

      type 'alias | grep foo'
      enter
      very_soon do
        expect(output).to_not match(/alias foo='echo bar'/)
      end
    end
  end
end
