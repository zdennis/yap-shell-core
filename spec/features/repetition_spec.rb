require 'spec_helper'

describe 'Repetition', type: :feature do
  describe 'N.times: statement' do
    it 'runs the line N times' do
      type '5.times : echo foo'
      enter
      expect { output }.to have_printed(/(.*foo){5}/m)
    end

    it 'is not white-space sensitive' do
      type '5.times               :                 echo foo'
      enter
      expect { output }.to have_printed(/(.*foo){5}/m)
    end
  end

  describe 'N.times: statement1 ; statement2' do
    it 'runs all the statements on the line N times' do
      type '3.times : echo foo ; echo bar'
      enter
      expect { output }.to have_printed(/(.*foo.*bar){3}/m)
    end

    it 'is not white-space sensitive' do
      type '3.times:echo foo ; echo bar'
      enter
      expect { output }.to have_printed(/(.*foo.*bar){3}/m)
    end
  end

  describe 'parameters' do
    it 'supplies an index for each execution' do
      type '3.times as n: echo foo$n ; echo bar$n '
      enter
      expect { output }.to have_printed(/foo1.*bar1.*foo2.*bar2.*foo3.*bar3/m)
    end

    it 'does not overwrite existing variables with the same name' do
      type "n='hello world'"
      enter
      type '3.times as n: echo $n'
      enter
      expect { output }.to have_printed(/1.*2.*3/m)
      clear_all_output

      type 'echo $n'
      enter
      expect { output }.to have_printed('hello world')
    end
  end

  describe 'repetition with blocks' do
    it 'runs the code inside the block N times' do
      type '4.times { echo foo }'
      enter
      expect { output }.to have_printed(/(.*foo){4}/m)
    end

    xit 'requires white-space before the opening curly brace' do
      # this breaks everything :(
      type '4.times{ echo foo }'
      enter
      expect { output }.to have_printed(/Infinite loop detected/m)
      skip 'Provide a better error message for the user.'
    end

    it 'requires white-space before the closing curly brace' do
      type '4.times { echo foo}'
      enter
      expect { output }.to have_printed(/Parse error/m)
      # should this be an error? Really? We can't tell that we're in a block
      # and we've got a closing curly brace right there?
      skip 'Provide a better error message for the user.'
    end

    it 'does not require white-space after the opening curly brace' do
      type '4.times {echo foo }'
      enter
      expect { output }.to have_printed(/(.*foo){4}/m)
    end

    it 'does not require white-space after the closing curly brace' do
      type '4.times { echo foo };'
      enter
      expect { output }.to have_printed(/Parse error/m)
      skip "This shouldn't be an error"
    end

    describe 'block parameters' do
      it 'supplies an index for each execution' do
        type 'echo beg ; 4.times { |n| echo $n } ; echo end'
        enter
        expect { output }.to have_printed(/beg.*\n.*1.*2.*3.*4.*\n.*end/m)
      end

      it 'does not overwrite existing variables with the same name' do
        type "n='hello world'"
        enter
        type 'echo beg ; 3.times { |n| echo $n } ; echo end'
        enter
        expect { output }.to have_printed(/beg.*\n.*1.*2.*3.*\n.*end/m)
        clear_all_output

        type 'echo $n'
        enter
        expect { output }.to have_printed('hello world')
      end

      it 'can step thru the repetition in groups based on how many block params are provided' do
        type 'echo beg ; 5.times { |a, b| echo $a $b } ; echo end'
        enter
        expect { output }.to have_printed(/beg.*\n.*1 2.*\n.*3 4.*\n.*5.*\n.*end/m)
      end
    end
  end

end
