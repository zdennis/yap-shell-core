class History
  class Group
    extend Forwardable

    def self.from_string(str)
      Group.new(started_at:nil, items:[Item.from_string(str)])
    end

    def self.from_hash(hsh)
      Group.new(
        command: hsh[:command],
        started_at: hsh[:started_at],
        stopped_at: hsh[:stopped_at],
        items: Item.from_array(hsh[:items])
      )
    end

    attr_reader :command

    def initialize(command:, started_at:Time.now, stopped_at:nil, items:[])
      @command = command
      @started_at = started_at
      @stopped_at = stopped_at
      @items = items
    end

    def_delegators :@items, :push, :<<, :pop, :first, :last

    def duration
      return nil unless @stopped_at
      total_seconds = @stopped_at - @started_at

      seconds = ((total_seconds % 60) * 10_000).to_i / 10_000.0
      minutes = ((total_seconds / 60) % 60).to_i
      hours = (total_seconds / (60 * 60)).to_i

      arr = []
      arr << sprintf("%d hr", hours) if hours == 1
      arr << sprintf("%d hrs", hours) if hours > 1
      arr << sprintf("%d min", minutes) if minutes == 1
      arr << sprintf("%d mins", minutes) if minutes > 1
      arr << sprintf("%.3f secs", seconds) if seconds > 0

      "less than a 10th of second" if arr.empty?

      arr.join(" ")
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

    def to_s
      @command
    end

    def to_h
      {
        command: @command,
        started_at: @started_at,
        stopped_at: @stopped_at,
        items: @items.map(&:to_h)
      }
    end

    #
    # Methods to conform to RawLine::HistoryBuffer expectations for
    # searching.
    #
    # def method_missing(name, *args, &blk)
    #   if @command.respond_to?(name)
    #     @command.send name, *args, &blk
    #   else
    #     super
    #   end
    # end
    def [](*args)
      @command[*args]
    end

    def chars
      @command.chars
    end

    def strip
      @command.strip!
    end

    def length
      @command.length
    end

    def each_byte(&blk)
      @command.each_byte(&blk)
    end

    def =~(rgx)
      @command =~ rgx
    end

  end
end
