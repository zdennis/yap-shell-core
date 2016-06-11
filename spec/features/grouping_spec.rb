require 'spec_helper'

describe 'Grouping commands', type: :feature do
  before do
    write_executable_script 'pass', <<-SCRIPT.strip_heredoc
      |#!/bin/sh
      |echo pass $1
      |exit 0
    SCRIPT

    write_executable_script 'fail', <<-SCRIPT.strip_heredoc
      |#!/bin/sh
      |echo fail $1
      |exit 1
    SCRIPT
  end

  describe 'using parentheses' do
    it 'works with: (command1 && command2) || command3' do
      type '(./pass 1 && ./fail 2) || ./pass 3'
      enter
      expect { output }.to have_printed(/pass 1.*fail 2.*pass 3/m)
      clear_all_output

      type '(./fail 1 && ./pass 2) || ./pass 3'
      enter
      expect { output }.to have_printed(/fail 1.*pass 3/m)
      expect { output }.to_not have_printed(/pass 2/m)
    end

    it 'works with: (command1 && command2 && command3) || command4' do
      type '(./pass 1 && ./fail 2 && ./pass 3) || ./pass 4'
      enter
      expect { output }.to have_printed(/pass 1.*fail 2.*pass 4/m)
      expect { output }.to_not have_printed(/pass 1.*fail 2.*pass 3.*pass 4/m)
      clear_all_output

      type '(./fail 1 && ./pass 2 && ./pass 3) || ./pass 4'
      enter
      expect { output }.to have_printed(/fail 1.*pass 4/m)
      expect { output }.to_not have_printed(/pass 2.*pass 3/m)
    end

    it 'works with: (command1 || command2) && command4' do
      type '(./fail 1 || ./pass 2) && ./pass 3'
      enter
      expect { output }.to have_printed(/fail 1.*pass 2.*pass 3/m)

      type '(./pass 1 || ./fail 2) && ./pass 3'
      enter
      expect { output }.to have_printed(/pass 1.*pass 3/m)
      expect { output }.to_not have_printed(/fail 2/m)
    end

    it 'works with: (command1 && command2) && command4' do
      type '(./fail 1 && ./pass 2) && ./pass 3'
      enter
      expect { output }.to have_printed(/fail 1/m)
      expect { output }.to_not have_printed(/.*pass 2.*pass 3/m)
      clear_all_output

      type '(./pass 1 && ./fail 2) && ./pass 3'
      enter
      expect { output }.to have_printed(/pass 1.*fail 2/m)
      expect { output }.to_not have_printed(/pass 3/m)
    end

    it 'works with: (command1 || command2) || command4' do
      type '(./fail 1 || ./pass 2) || ./pass 3'
      enter
      expect { output }.to have_printed(/fail 1.*pass 2/m)
      expect { output }.to_not have_printed(/pass 3/m)

      type '(./pass 1 || ./fail 2) || ./pass 3'
      enter
      expect { output }.to have_printed(/pass 1/m)
      expect { output }.to_not have_printed(/fail 2.*pass 3/m)
    end
  end

end
