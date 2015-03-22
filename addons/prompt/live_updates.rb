require 'terminfo'

class LiveUpdates < Addon
  attr_reader :world

  def initialize_world(world)
    @world = world
    thr = Thread.new do
      loop do
        sleep 1

        # Make sure we're in the foreground otherwise trying Error::EIO will be
        # thrown trying to talk to STDOUT.
        if world.foreground?
          begin
            redraw_prompt
          rescue Errno::EIO => ex
          end
        end
      end
    end
    thr.abort_on_exception = true
  end

  private

  def redraw_prompt
    t = TermInfo.new(ENV["TERM"], STDOUT)

    current_text = world.prompt.text
    next_text = world.prompt.update.text

    if current_text != next_text
      buffer = Readline.line_buffer

      # capture where the readline cursor currently is
      cursor_xpos = Readline.point

      # clear to end of line (in case we're shortening the line)
      t.control "el", 1

      # clear to beginning of the line
      t.control "el1", 1

      # move cursor to the first column of the current row
      t.control "cr", 1

      # reprint the entire line
      print next_text, buffer
      Readline.redisplay

      # Move the cursor to where readline thinks it is based on the new prompt size
      t.control 'hpa', next_text.gsub(/\033\[[0-9;]*m/, "").length + cursor_xpos
    end
  end

end
