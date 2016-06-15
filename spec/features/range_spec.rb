require 'spec_helper'

describe 'Ranges', type: :feature do
  describe 'line repetition: (M..N): statement' do
    it 'runs the line N times' do
      type '(0..2) : echo foo'
      enter
      expect { output }.to have_printed(/(.*foo){3}/m)
    end
  end

  describe 'line repetition w/parameter: (M..N) as n: statement' do
    it 'runs the line N times supplying an index' do
      type '(0..2) as n: echo foo $n'
      enter
      expect { output }.to have_printed(/foo 0.*\n.*foo 1.*\n.*foo 2/m)
    end
  end

  describe 'block repetition: (M..N) { statement } ; echo bar' do
    it 'runs the block N times' do
      type 'echo baz; (0..2) { echo foo } ; echo bar'
      enter
      expect { output }.to have_printed(/baz.*\n(.*foo){3}.*\n.*bar/m)
    end
  end

  describe 'block repetition w/parameter: (M..N) { |n| statement }' do
    it 'runs the block N times supplying an index' do
      type 'echo baz ; (0..2) { |n| echo foo $n } ; echo bar'
      enter
      expect { output }.to have_printed(/baz.*\n.*foo 0.*\n.*foo 1.*\n.*foo 2.*\n.*bar/m)
    end
  end
end
