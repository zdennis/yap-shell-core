require 'forwardable'
module Yap
  module WorldAddons
    class History
      def self.load_addon
        instance
      end

      def self.instance
        @history ||= History.new
      end

      def initialize
        @history = []
      end

      def initialize_world(world)
        load_history

        world.func(:howmuch) do |args:, stdin:, stdout:, stderr:|
          case args.first
          when "time"
            if history_item=self.last_executed_item
              stdout.puts history_item.total_time_s
            else
              stdout.puts "Can't report on something you haven't done."
            end
          else
            stdout.puts "How much what?"
          end
        end
      end

      def executing(command:, started_at:)
        raise "Cannot acknowledge execution beginning of a command when no group has been started!" unless @history.last
        @history.last.executing command:command, started_at:started_at
      end

      def executed(command:, stopped_at:)
        raise "Cannot complete execution of a command when no group has been started!" unless @history.last
        @history.last.executed command:command, stopped_at:stopped_at
      end

      def last_executed_item
        @history.reverse.each do |group|
          last_run = group.last_executed_item
          break last_run if last_run
        end
      end

      def start_group(started_at)
        @history.push Group.new(started_at:started_at)
      end

      def stop_group(stopped_at)
        @history.last.stopped_at(stopped_at)
      end

      private

      def history_file
        @history_file ||= File.expand_path('~') + '/.yap-history'
      end

      def load_history
        return unless File.exists?(history_file) && File.readable?(history_file)
        (YAML.load_file(history_file) || []).each do |item|
          ::Readline::HISTORY.push item
        end

        at_exit do
          File.write history_file, ::Readline::HISTORY.to_a.to_yaml
        end
      end

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

      Yap::Shell::Execution::Context.on(:before_statements_execute) do |context|
        puts "Before group: #{context.to_s}" if ENV["DEBUG"]
        History.instance.start_group(Time.now)
      end

      Yap::Shell::Execution::Context.on(:after_statements_execute) do |context|
        History.instance.stop_group(Time.now)
        puts "After group: #{context.to_s}" if ENV["DEBUG"]
      end

      Yap::Shell::Execution::Context.on(:after_process_finished) do |context, *args|
        # puts "After process: #{context.to_s}, args: #{args.inspect}"
      end

      Yap::Shell::Execution::Context.on(:before_execute) do |context, command:|
        History.instance.executing command:command.str, started_at:Time.now
      end

      Yap::Shell::Execution::Context.on(:after_execute) do |context, command:, result:|
        History.instance.executed command:command.str, stopped_at:Time.now
      end

    end
  end
end
