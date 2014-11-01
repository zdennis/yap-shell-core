require 'thread'
require 'yaml'

module Lagniappe
  class Console
    def self.queue
      @queue ||= Queue.new
    end

    attr_reader :world

    def initialize(io_in:$stdin, prompt:"> ")
      @io_in = io_in
      @prompt = prompt
      @world = World.new(prompt: prompt)
    end

    def preload_shells(n=1)
      @shells ||= n.times.map{ Shell.new }
      return unless File.exists?(history_file)
      (YAML.load_file(history_file) || []).each do |item|
        ::Readline::HISTORY.push item
      end
    end

    def history_file
      File.expand_path('~') + '/.lagniappe-history'
    end

    def parse_command(command)
      scope = []
      words = []
      str = ''

      command.each_char.with_index do |ch, i|
        popped = false
        if scope.last == ch
          scope.pop
          popped = true
        end

        if (scope.empty? && ch == "|") || (i == command.length - 1)
          str << ch unless ch == "|"
          words << str.strip
          str = ''
        else
          if !popped
            if %w(' ").include?(ch)
              scope << ch
            elsif ch == "{"
              scope << "}"
            elsif ch == "["
              scope << "]"
            end
          end
          str << ch
        end
      end

      words
    end

    def parse_commands(line)
      # command, heredoc = line.scan(/(.*?)(<<-?(\S+).*\3)?/m).flatten[0..1]
      # *command_parts, heredoc, delimiter = line.scan(/(<<-?(\S+).*\2\s*$)|(\S+)/m)
      #command = command_parts.join
      command = line.split(/\s*<<-?(\S+).*\1$/m).first
      heredoc = line[command.length..-1] if command.length < line.length

      words = parse_command command
      words.map { |f| f[0] == "!" ? [f] : f.shellsplit }.tap do |arr|
        arr.last << heredoc if heredoc
      end
    end

    def run
      preload_shells

      at_exit do
        File.write history_file, ::Readline::HISTORY.to_a.to_yaml

        Dir["fifo-test-*"].each do |f|
          (FileUtils.rm f rescue nil)
        end
      end

      STDOUT.sync = true

      shell = @shells.first
      shell.open_pty

      t = Thread.new do
        status_code = nil
        begin
          loop do
            puts shell.pty_master.read_nonblock(8192)
          end
        rescue IO::EAGAINWaitReadable
          if output = (shell.stdout.read_nonblock(8192) rescue nil)
            status_code = output.chomp
            Console.queue.enq status_code
            status_code = should_exit = nil
            retry
          else
            retry
          end
        end
      end

      loop do
        # print "\033[s\033[100;0H #{Time.now}\033[u"
        line = Readline.readline("#{world.prompt}", true)
        line.strip!
        next if line == ""

        if line =~ /<<(-)?(\S+)/
          puts "Beginning heredoc"
          # heredoc
          line << "\n"
          allow_whitespace = !!$1
          end_marker = $2
          loop do
            print "> "
            str = gets
            line << str
            if str.to_s =~ /^#{Regexp.escape(end_marker)}/
              puts "BREAK"
              break
            end
          end
        else
          puts "No heredoc"
        end

        puts "line is now #{line.inspect}"
        commands = parse_commands(line)
        pipes = []

        commands.reverse.map.with_index do |command, i|
          last_item = (commands.length - 1) == i
          command = command.flatten.join " "
          exit if command == "exit"

          ruby_command = command.scan(/^\!(.*)/).flatten.first

          pipe_out, pipe_in = if commands.length == 1
            [shell.pty_slave.path, shell.pty_master]
          elsif last_item
            [pipes.last.pipe_in, nil]
          elsif i == 0
            [shell.pty_slave.path, "fifo-test-#{i*2+1}"]
            # ["fifo-test-#{i*2}", "fifo-test-#{i*2+1}"]
          else
            [pipes.last.pipe_in, "fifo-test-#{i+1}"]
          end
          pipes << OpenStruct.new(pipe_in: pipe_in, pipe_out: pipe_out)
          puts pipes.last.inspect if ENV["DEBUG"]

          if pipe_in && !last_item
            puts "Pipe: #{pipe_in}" if ENV["DEBUG"]
            File.mkfifo pipe_in unless File.exists?(pipe_in)
            command << " < #{pipe_in}"
          end

          if pipe_out.is_a?(String)
            unless File.exists?(pipe_out)
              puts "Pipe: #{pipe_out}" if ENV["DEBUG"]
              File.mkfifo pipe_out  unless File.exists?(pipe_out)
            end
            command << " > #{pipe_out}"
          elsif pipe_out.is_a?(IO)
            puts "IO Pipe: #{pipe_out}" if ENV["DEBUG"]
            command << " > #{pipe_out.path}"
          end

          world = self.world
          if ruby_command
            puts "ruby: #{ruby_command} < #{pipe_in} > #{pipe_out}" if ENV["DEBUG"]
            Thread.new {
              exit_code = 0

              f = nil
              str = ""
              begin
                contents = if pipe_in.is_a?(String)
                  f = File.open(pipe_in)
                  f.read
                else
                  ""
                end
                puts "READ: #{contents.length} bytes from #{pipe_in}" if ENV["DEBUG"]
                world.contents = contents

                method = ruby_command.scan(/^(\w+(?:[!?]|\s*=)?)/).flatten.first.gsub(/\s/, '')
                puts "method: #{method}" if ENV["DEBUG"]
                obj = if world.respond_to?(method)
                  world
                elsif contents.respond_to?(method)
                  contents
                else
                  world
                end

                ruby_command = "self.#{ruby_command}"

                puts "Evaluating #{ruby_command} on #{obj.inspect}" if ENV["DEBUG"]
                str = obj.instance_eval ruby_command
              rescue Exception => ex
                str = <<-EOT.gsub(/^\s*\S/, '')
                  |Failed processing ruby: #{ruby_command}
                  |#{ex}
                  |#{ex.backtrace.join("\n")}
                EOT
                exit_code = 1
              ensure
                f.close if f && !f.closed?
              end

              f2 = File.open(pipe_out, "w")
              f2.sync = true
              # The next line  causes issues sometimes?
              # puts "WRITING #{str.length} bytes" if ENV["DEBUG"]
              f2.flush
              f2.write str

              f2.close

              # Make up an exit code
              shell.stdin.puts "#{commands.length - i}/#{commands.length}:#{exit_code}"
            }

          elsif pipe_in and pipe_out
            command = "( #{command} ; echo \"#{commands.length - i}/#{commands.length}:$?\" ) &"
          end

          unless ruby_command
            puts command if ENV["DEBUG"]
          end

          puts if ENV["DEBUG"]

          shell.puts command unless ruby_command
          command
        end

        loop do
          v = Console.queue.deq
          puts "DEQ'd #{v}" if ENV["DEBUG"]
          if v =~ /^(\d+)\/(\d+)/
            a, b = $1.to_i, $2.to_i
            break if a == b # last command in chain
          end
        end
      end
    end

    private

    def builtin?(program)
      builtins.has_key?(program)
    end

    def call_builtin(program, *arguments)
      builtins[program].call(*arguments)
    end

    def builtins
      {
        'cd' => lambda { |dir = ENV["HOME"]| Dir.chdir(dir) },
        'exit' => lambda { |code = 0| exit(code.to_i) },
        'exec' => lambda { |*command| exec *command },
        'set' => lambda { |args|
          key, value = args.split('=')
          ENV[key] = value
        }
      }
    end
  end

end
