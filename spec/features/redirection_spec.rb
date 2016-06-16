require 'spec_helper'

describe 'I/O Redirection', type: :feature do
  before do
    write_executable_script 'fail', <<-SCRIPT.strip_heredoc
      |#!/bin/sh
      |>&2 echo fail $1
      |exit 1
    SCRIPT
  end

  describe 'STDOUT' do
    it 'redirects with: >' do
      type 'echo foo > output.txt'
      enter
      clear_all_output

      type 'cat output.txt'
      enter
      expect { output }.to have_printed('foo')
    end

    it 'redirects with: 1>' do
      type 'echo hrm 1> output.txt'
      enter
      clear_all_output

      type 'cat output.txt'
      enter
      expect { output }.to have_printed('hrm')
    end

    it 'overwrites the file' do
      type 'echo foo > output.txt'
      enter
      type 'echo bar > output.txt'
      enter
      clear_all_output

      type 'cat output.txt'
      enter
      expect { output }.to have_printed('bar')
      expect { output }.to have_not_printed('foo')
    end

    describe 'appending' do
      before do
        type 'echo foo > output.txt'
        enter
        type 'cat output.txt'
        enter
        expect { output }.to have_printed(/foo/)
        clear_all_output
      end

      it 'appends with: >>' do
        type 'echo bar >> output.txt'
        enter
        type 'cat output.txt'
        enter
        expect { output }.to have_printed(/foo.*\n.*bar/)
      end

      it 'appends with: 1>>' do
        type 'echo bar 1>> output.txt'
        enter
        type 'cat output.txt'
        enter
        expect { output }.to have_printed(/foo.*\n.*bar/)
      end
    end
  end

  describe 'STDERR' do
    it 'redirects with: 2>' do
      type './fail foo 2> error.txt'
      enter
      clear_all_output

      type 'cat error.txt'
      enter
      expect { output }.to have_printed('fail foo')
    end

    it 'overwrites the file' do
      type './fail foo 2> error.txt'
      enter
      type './fail bar 2> error.txt'
      enter
      clear_all_output

      type 'cat error.txt'
      enter
      expect { output }.to have_printed('fail bar')
      expect { output }.to have_not_printed('fail foo')
      clear_all_output
    end

    describe 'appending' do
      before do
        type './fail caz 2> error.txt'
        enter
        type 'cat error.txt'
        enter
        expect { output }.to have_printed(/fail caz/)
        clear_all_output
      end

      it 'appends with: 2>>' do
        type './fail box 2>> error.txt'
        enter
        type 'cat error.txt'
        enter
        expect { output }.to have_printed(/fail caz.*\n.*fail box/)
      end
    end
  end

  describe 'STDOUT and STDERR separately for a command' do
    before do
      write_executable_script 'print-stuff', <<-SCRIPT.strip_heredoc
        |#!/bin/sh
        |echo 'normal foo'
        |(>&2 echo 'error foo')
      SCRIPT
    end

    it 'redirects with: > and 2>' do
      type './print-stuff > stdout.txt 2> stderr.txt'
      enter
      clear_all_output

      type 'cat stdout.txt'
      enter
      expect { output }.to have_printed('normal foo')
      clear_all_output

      type 'cat stdout.txt'
      enter
      expect { output }.to have_not_printed('error foo')
      clear_all_output

      type 'cat stderr.txt'
      enter
      expect { output }.to have_printed('error foo')
      clear_all_output

      type 'cat stderr.txt'
      enter
      expect { output }.to have_not_printed('normal foo')
    end

    it 'redirects with: 1> and 2>' do
      type './print-stuff 1> stdout.txt 2> stderr.txt'
      enter
      clear_all_output

      type 'cat stdout.txt'
      enter
      expect { output }.to have_printed('normal foo')
      clear_all_output

      type 'cat stdout.txt'
      enter
      expect { output }.to have_not_printed('error foo')
      clear_all_output

      type 'cat stderr.txt'
      enter
      expect { output }.to have_printed('error foo')
      clear_all_output

      type 'cat stderr.txt'
      enter
      expect { output }.to have_not_printed('normal foo')
    end
  end

  describe 'STDOUT and STDERR pointing to the same file' do
    before do
      write_executable_script 'echo-stdout-and-stderr', <<-SCRIPT.strip_heredoc
        |#!/bin/sh
        |echo $1
        |>&2 echo $2
      SCRIPT
    end

    it 'redirects and overwrites with: &>' do
      type './echo-stdout-and-stderr foo bar &> output-and-error.txt'
      enter
      type 'cat output-and-error.txt'
      enter
      expect { output }.to have_printed(/foo.*\n.*bar/m)
    end

    it 'redirects and overwrites with: 2>&1' do
      type './echo-stdout-and-stderr bar foo 2>&1 output-and-error.txt'
      enter
      type 'cat output-and-error.txt'
      enter
      expect { output }.to have_printed(/bar.*\n.*foo/m)
    end

    it 'redirects and appends with: &>>' do
      type './echo-stdout-and-stderr howdy hey &>> output-and-error.txt'
      enter
      type 'cat output-and-error.txt'
      enter
      expect { output }.to have_printed(/howdy.*\n.*hey/m)
    end
  end

  describe 'STDIN' do
    it 'redirect  with: <' do
      type 'echo foo > stdin.txt'
      enter
      clear_all_output

      type 'cat < stdin.txt'
      enter
      expect { output }.to have_printed('foo')
    end
  end

end
