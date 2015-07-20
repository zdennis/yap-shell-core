class History
  class Buffer < Array
    attr_reader :position, :size
    attr_accessor :duplicates, :exclude, :cycle

    #
    # Create an instance of History::Buffer.
    # This method takes an optional block used to override the
    # following instance attributes:
    # * <tt>@duplicates</tt> - whether or not duplicate items will be stored in the buffer.
    # * <tt>@exclude</tt> - a Proc object defining exclusion rules to prevent items from being added to the buffer.
    # * <tt>@cycle</tt> - Whether or not the buffer is cyclic.
    #
    def initialize(size)
      @duplicates = true
      @exclude = lambda{|a|}
      @cycle = false
      yield self if block_given?
      @size = size
      @position = nil
    end

    def supports_partial_text_matching?
      true
    end

    def supports_matching_text?
      true
    end

    #
    # Clears the current position on the history object. Useful when deciding
    # to cancel/reset history navigation.
    #
    def clear_position
      @position = nil
    end

    def searching?
      !!@position
    end

    #
    # Resize the buffer, resetting <tt>@position</tt> to nil.
    #
    def resize(new_size)
      if new_size < @size
        @size-new_size.times { pop }
      end
      @size = new_size
      @position = nil
    end

    #
    # Clear the content of the buffer and reset <tt>@position</tt> to nil.
    #
    def empty
      @position = nil
      clear
    end

    #
    # Retrieve a copy of the element at <tt>@position</tt>.
    #
    def get
      return nil unless length > 0
      return nil unless @position
      at(@position).command.dup
    end

    #
    # Return true if <tt>@position</tt> is at the end of the buffer.
    #
    def end?
      @position == length-1
    end

    #
    # Return true if <tt>@position</tt> is at the start of the buffer.
    #
    def start?
      @position == 0
    end

    #
    # Decrement <tt>@position</tt>. By default the history will become
    # positioned at the previous item.
    #
    def back(options={})
      return nil unless length > 0
      @position = search_back(options) || @position
    end

    #
    # Increment <tt>@position</tt>. By default the history will become
    # positioned at the next item.
    #
    def forward(options={})
      return nil unless length > 0
      @position = search_forward(options) || @position
    end

    #
    # Add a new item to the buffer.
    #
    def push(item)
      if !@duplicates && self[-1] == item
        # skip adding this line
        return
      end

      unless @exclude.call(item)
        # Remove the oldest element if size is exceeded
        if @size <= length
          reverse!.pop
          reverse!
        end
        # Add the new item and reset the position
        super(item)
        @position = nil
      end
    end

    alias << push

    def to_yaml(range=(0..-1))
      self[range].map do |element|
        element.kind_of?(String) ? element : element.to_h
      end.to_yaml
    end

    private

    def search_back(matching_text:)
      command_history = map(&:command)
      $z.puts "starting position: #{position.inspect} #{@position.inspect}"
      upto_index = (position || length) - 1
      current = get

      $z.puts
      $z.puts <<-EOS.gsub(/^\s*\|/, '')
        |Search backward:
        |    current:#{current.inspect}
        |    history: #{command_history.inspect}
        |    history position: #{position}
        |    matching_text: #{matching_text.inspect}
        |    upto_index: #{upto_index}
        |    snapshot: #{command_history[0..upto_index].reverse.inspect}
      EOS

      return position unless upto_index >= 0

      snapshot = command_history[0..upto_index].reverse
      no_match = nil

      position = snapshot.each_with_index.reduce(no_match) do |no_match, (text, i)|
        $z.print "    - matching #{text.inspect} =~ /^#{matching_text.to_s}/ && #{current} != #{text} : "
        if text =~ /^#{Regexp.escape(matching_text.to_s)}/ && current != text
          $z.puts "  match #{i}, returning position #{snapshot.length - (i + 1)}"

          # convert to non-reversed indexing
          position = snapshot.length - (i + 1)
          break position
        else
          $z.puts " no match."
          no_match
        end
      end
    end

    def search_forward(matching_text:)
      command_history = map(&:command)
      return nil unless position

      start_index = position + 1
      snapshot = command_history[start_index..-1].dup
      no_match = nil
      current = get

      position = snapshot.each_with_index.reduce(no_match) do |no_match, (text, i)|
        if text =~ /^#{Regexp.escape(matching_text.to_s)}/ && current != text
          position = start_index + i
          break position
        else
          no_match
        end
      end
    end
  end

end
