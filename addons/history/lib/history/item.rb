class History
  class Item
    attr_reader :command

    def initialize(command:command, started_at:Time.now)
      @command = command
      @started_at = started_at
      @ended_at = nil
    end

    def finished!(at)
      @ended_at = at
    end

    def finished?
      !!@ended_at
    end

    def total_time_s
      humanize(@ended_at - @started_at) if @ended_at && @started_at
    end

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
