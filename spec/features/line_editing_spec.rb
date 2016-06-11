require 'spec_helper'

describe 'Line editing', type: :feature do
  let(:left_arrow) { [?\e, ?[, ?D].join }
  let(:right_arrow) { [?\e, ?[, ?C].join }
  let(:backspace){ [?\C-?].join }
  let(:delete){ [?\e, ?[, ?3, ?~].join }

  it 'Left/Right arrow keys move cursor one position left/right' do
    # cursor is right the 'o'
    type 'echo hli'

    # let's fix this
    type left_arrow
    type left_arrow
    type 'e'

    type right_arrow
    type right_arrow
    type 'copter'
    enter
    expect { output }.to have_printed('helicopter')
  end

  it 'Backspace deletes one character left of the cursor, moving the cursor with it' do
    type 'echo hello worfd'
    type left_arrow
    type backspace
    type 'l'
    enter
    expect { output }.to have_printed('hello world')
  end

  it 'Delete deletes the character under the cursor, leaving the cursor where it is' do
    type 'echo hello world'
    6.times { type left_arrow }
    6.times { type delete }
    enter
    expect { output }.to have_printed('hello')
    expect { output }.to_not have_printed('world')
  end

  describe 'line navigation (default key bindings)' do
    it 'Ctrl-a moves to beginning of line' do
      type 'o hello world'
      type ?\C-a
      type 'ech'
      enter
      expect { output }.to have_printed('hello world')
    end

    it 'Ctrl-e moves to end of line' do
      type 'o hello'
      type ?\C-a
      type 'ech'
      type ?\C-e
      type ' world'
      enter
      expect { output }.to have_printed('hello world')
    end

    it 'Ctrl-b moves backward one line at a time' do
      type 'echo hello ld'
      type ?\C-b
      type 'wor'
      enter
      expect { output }.to have_printed(/^hello world/)
      clear_all_output

      type 'echo hello world' #, ?\C-b, ?\C-b, 'foo'].join
      type ?\C-b
      type ?\C-b
      type 'foo '
      enter
      expect { output }.to have_printed(/^foo hello world/)
    end

    it 'Ctrl-f moves forward one word at a time' do
      type 'echo hello world'
      type ?\C-a
      type ?\C-f
      type 'bob says '
      enter
      expect { output }.to have_printed('bob says hello world')
      clear_all_output

      type 'echo hello world'
      type ?\C-a
      type ?\C-f
      type ?\C-f
      type 'foo '
      enter
      expect { output }.to have_printed('hello foo world')
    end

    it 'Ctrl-k kills text forward from the cursor position' do
      type 'echo hello world'
      type ?\C-b
      type ?\C-k
      enter
      expect { output }.to have_printed('hello')
      clear_all_output

      type 'echo hello world'
      type ?\C-b
      type ?\C-b
      type ?\C-k
      type 'foo'
      enter
      expect { output }.to have_printed('foo')
    end

    it 'Ctrl-y does not insert when there is no killed text' do
      type 'echo "hello world"'
      type left_arrow
      type ?\C-y
      enter
      expect { output }.to have_printed('hello world')
      clear_all_output
    end

    it 'Ctrl-y inserts the last killed text where the cursor is' do
      type 'echo hello world'
      type ?\C-b
      type ?\C-k
      type 'delightful '
      type ?\C-y
      enter
      expect { output }.to have_printed('hello delightful world')
      clear_all_output
    end

    it 'Ctrl-w deletes a word backwards, adding it to the kill ring' do
      type 'echo hello world'
      type ?\C-w
      enter
      expect { output }.to have_printed('hello')
      clear_all_output

      type 'echo hello world'
      type ?\C-w
      type ?\C-w
      type 'nope'
      enter
      expect { output }.to have_printed('nope')
      expect { output }.to_not have_printed('hello world')

      type 'echo '
      type ?\C-y
      enter
      expect { output }.to have_printed('hello')
      expect { output }.to_not have_printed('hello')
    end

    it 'Ctrl-u deletes from the cursor to the beginning of the line, adding to the killing as ring' do
      type 'echo hello world'
      type ?\C-u
      type 'echo '
      type ?\C-y
      enter
      expect { output }.to have_printed('echo hello world')
    end

  end

end
