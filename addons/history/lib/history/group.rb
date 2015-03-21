class History
  class Group
    extend Forwardable

    def initialize(started_at:Time.now)
      @started_at = started_at
      @stopped_at = nil
      @items = []
    end

    def_delegators :@items, :push, :<<, :pop, :first, :last

    def duration
      return nil unless @stopped_at
      @stopped_at - @started_at
    end

    def executing(command:, started_at:)
      @items.push Item.new(command:command, started_at:started_at)
    end

    def executed(command:, stopped_at:)
      raise "2:Cannot complete execution of a command when no group has been started!" unless @items.last
      item = @items.reverse.detect do |item|
        command == item.command && !item.finished?
      end
      item.finished!(stopped_at)
    end

    def last_executed_item
      @items.reverse.detect{ |item| item.finished? }
    end

    def stopped_at(time)
      @stopped_at ||= time
    end
  end
end
