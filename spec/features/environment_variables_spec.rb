require 'spec_helper'

describe 'Environment variables', type: :feature do
  it 'sets and gets them' do
    type 'FOO=foobarbaz'
    enter

    type 'echo $FOO'
    enter
    expect { output }.to have_printed('foobarbaz')
  end

  it 'expands env vars inside of double quotes' do
    type 'BAR=foobarbaz'
    enter

    type %|echo "BAR is $BAR"|
    enter
    expect { output }.to have_printed('BAR is foobarbaz')
  end

  it 'does not expand env vars inside of single quotes' do
    type 'BAR=foobarbaz'
    enter

    type %|echo 'BAR is $BAR'|
    enter
    expect { output }.to have_printed('BAR is $BAR')
  end

  describe 'setting env vars for a single statement' do
    it 'makes the env var available to the statement' do
      type 'BAZ=baz echo $BAZ'
      enter
      expect { output }.to have_printed('baz')
    end

    it 'does not keep the env var around for the next statement' do
      type 'BAZ=baz echo $BAZ'
      enter
      clear_all_output

      type 'echo $BAZ'
      enter
      expect { output }.to have_printed('$BAZ')
    end

    it 'can set multiple env vars for a statement' do
      type %|FOO=foo BAR='is the' BAZ="fastest pineapple" echo $FOO $BAR $BAZ|
      enter
      expect { output }.to have_printed('foo is the fastest pineapple')
    end
  end
end
