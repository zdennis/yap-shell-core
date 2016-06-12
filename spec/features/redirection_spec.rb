require 'spec_helper'

describe 'I/O Redirection', type: :feature do
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

    it 'appends with: >>'
  end

  describe 'STDERR' do
    it 'redirects with: 2>' do
      type 'echo foo > error.txt'
      enter
      clear_all_output

      type 'cat error.txt'
      enter
      expect { output }.to have_printed('foo')
    end

    it 'overwrites the file' do
      type 'echo foo > error.txt'
      enter
      type 'echo bar > error.txt'
      enter
      clear_all_output

      type 'cat error.txt'
      enter
      expect { output }.to have_printed('bar')
      clear_all_output

      type 'cat error.txt'
      enter
      expect { output }.to have_not_printed('foo')
    end

    it 'appends with: 2>>'
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
    it 'redirects and overwrites with: &>'

    it 'redirects and overwrites with: 2>&1'

    it 'redirects and appends with: &>>'
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
