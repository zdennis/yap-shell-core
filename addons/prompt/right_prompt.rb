require 'terminfo'

module Yap
  module WorldAddons
    module Prompt
      class RightPrompt
        include Term::ANSIColor

        attr_reader :word, :term_info

        def self.load_addon
          @instance ||= new
        end

        def initialize_world(world)
          @term_info = TermInfo.new("xterm-256color", STDOUT)
          @world = world

          Signal.trap("SIGWINCH") do
            # clear to end of line (in case we're shortening the line)
            @term_info.control "ed", 1
            Readline.redisplay
          end

          @thr = Thread.new do
            loop do
              sleep 1

              # Make sure we're in the foreground otherwise trying Error::EIO will be
              # thrown trying to talk to STDOUT
              if world.foreground?
                begin
                  buffer = Readline.line_buffer
                  prompt_text = world.prompt.text.gsub(/\033\[[0-9;]*m/, "")

                  if is_overlapping_right_prompt?(prompt_text.length + buffer.length)
                    # clear to end of line
                    term_info.control "el", 1
                  else
                    draw_prompt
                  end
                  #on: :previous_row
                rescue Errno::EIO => ex
                end
              end
            end
          end
          @thr.abort_on_exception = true
        end

        private

        def is_overlapping_right_prompt?(position)
          @right_prompt_position && position >= @right_prompt_position
        end

        def draw_prompt(on:nil)
          time_str = Time.now.strftime("%H:%M:%S")
          time_str_without_ansii = time_str.gsub(/\033\[[0-9;]*m/, "")
          h, w = term_info.screen_size
          term_info.control "sc"
          term_info.control "cub", w
          if on == :previous_row
            term_info.control "cuu", 1
          end

          @right_prompt_position = w - time_str_without_ansii.length
          term_info.control "cuf", @right_prompt_position
          term_info.write bright_black(time_str)
          term_info.control "rc"
        end
      end
    end
  end
end
