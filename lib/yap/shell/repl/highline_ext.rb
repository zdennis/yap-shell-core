require 'highline/system_extensions'
require 'io/console'

module HighLine::SystemExtensions
  def get_character( input = STDIN )
    input.raw do
      ch = input.getbyte
      ch
    end
  rescue Exception => ex
    require 'pry'
    binding.pry
  end
end
