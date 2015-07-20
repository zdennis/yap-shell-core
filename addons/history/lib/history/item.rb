require 'delegate'

class History
  class Item
    attr_reader :command

    def self.from_string(str)
      Item.new(command:str, started_at:nil, stopped_at:nil)
    end

    def self.from_array(items)
      items.map do |hsh|
        Item.new(
          command: hsh[:command],
          started_at: hsh[:started_at],
          stopped_at: hsh[:stopped_at]
        )
      end
    end

    def initialize(command:command, started_at:Time.now, stopped_at:nil)
      @command = command
      @started_at = started_at
      @stopped_at = nil
    end

    def finished!(at)
      @stopped_at = at
    end

    def finished?
      !!@stopped_at
    end

    def total_time_s
      humanize(@stopped_at - @started_at) if @stopped_at && @started_at
    end

    def to_h
      {
        command: @command,
        started_at: @started_at,
        stopped_at: @stopped_at
      }
    end

    #
    # Methods to conform to RawLine::HistoryBuffer expectations
    #
    # def strip
    #   @command.strip!
    # end

    private

    def humanize secs
      [[60, :seconds], [60, :minutes], [24, :hours], [1000, :days]].inject([]){ |s, (count, name)|
        if secs > 0
          secs, n = secs.divmod(count)
          s.unshift "#{n} #{name}"
        end
        s
      }.join(' ')
    end
  end
end
