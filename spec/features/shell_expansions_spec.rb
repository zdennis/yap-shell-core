require 'spec_helper'

describe 'Shell expansions', type: :feature do
  describe 'aliases' do
    before do
      type 'alias foo="echo bar"'
      enter
      expect { output }.to have_printed('Setting alias foo')
    end

    it 'expands aliases found in command position' do
      type 'foo'
      enter
      expect { output }.to have_printed('bar')
    end

    it 'does not expand aliases found in argument position' do
      type 'echo foo'
      enter
      expect { output }.to have_printed('foo')
      expect { output }.to_not have_printed('bar')
    end
  end

  describe 'environment variable expansion' do
    it 'expands upper-case env vars with a preceding $' do
      type 'FOO=bar echo $FOO'
      enter
      expect { output }.to have_printed('bar')
    end

    it 'expands lower-case vars with a preceding $' do
      type 'foo=bar echo $foo'
      enter
      expect { output }.to have_printed('bar')
    end

    it 'is case sensitive' do
      type 'foo=bar echo $foo'
      enter
      expect { output }.to have_printed('bar')

      type 'echo $FOO'
      enter
      expect { output }.to have_printed('$FOO')
    end

    it 'does not expand escaped env vars' do
      type 'FOO=bar echo \\$FOO'
      enter
      expect { output }.to have_printed('$FOO')
    end
  end

  describe 'exit status for last command: $?' do
    it 'prints whatever the exit status of the last command was' do
      write_executable_script 'exit-with-status-code', <<-SCRIPT.strip_heredoc
        |#!/bin/sh
        |exit $1
      SCRIPT

      type './exit-with-status-code 0 ; echo $?'
      enter
      expect { output }.to have_printed('0')

      type './exit-with-status-code 1 ; echo $?'
      enter
      expect { output }.to have_printed('1')

      type './exit-with-status-code 99 ; echo $?'
      enter
      expect { output }.to have_printed('99')
    end
  end

  describe 'word expansions using curly braces' do
    it 'expands in command position' do
      type 'foo_{}'
      enter
      expect { error_output }.to have_printed('yap: command not found: foo_')
    end

    describe 'arguments' do
      it 'expands no words' do
        type 'echo foo_{}'
        enter
        expect { output }.to have_printed('foo_')
      end

      it 'expands single words' do
        type 'echo foo_{bar}'
        enter
        expect { output }.to have_printed('foo_bar')
      end

      it 'multiple words in comma-separated list' do
        type 'echo foo_{bar,bay,baz}'
        enter
        expect { output }.to have_printed('foo_bar foo_bay')
      end

      it 'expands environment variables' do
        type 'FOO=huzzah echo foo_{$FOO}'
        enter
        expect { output }.to have_printed('foo_huzzah')
      end

      it 'does not expand environment variables in double quotes' do
        type 'FOO=huzzah echo foo_{"$FOO"}'
        enter
        expect { output }.to have_printed('foo_{$FOO}')
      end

      it 'does not expand environment variables in single quotes' do
        type %|FOO=huzzah echo foo_{'$FOO'}|
        enter
        expect { output }.to have_printed('foo_{$FOO}')
      end

      it 'treats ~ as any a normal character, not home directory expansion' do
        type 'echo foo_{~}'
        enter
        expect { output }.to have_printed('foo_~')
      end
    end
  end
end
