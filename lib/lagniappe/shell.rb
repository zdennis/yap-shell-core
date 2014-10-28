require 'shellwords'
require 'readline'
require 'term/ansicolor'
require 'mkfifo'
require 'ostruct'
require 'pty'

module Lagniappe
  def self.run_console
    Console.new.run
  end

  class World
    include Term::ANSIColor

    attr_accessor :prompt

    def initialize(options)
      (options || {}).each do |k,v|
        self.send "#{k}=", v
      end
    end
  end

  require 'childprocess'
  class Shell
    attr_reader :pty_master, :pty_slave

    def initialize
      @r, @w = IO.pipe
      @childprocess = build_childprocess
      @childprocess.start
      @available = true
    end

    def open_pty
      @pty_master.close if @pty_master
      @pty_slave.close  if @pty_slave
      @pty_master, @pty_slave = PTY.open
    end

    def available?
      @available
    end

    def stdout
      @childprocess.io.stdout
    end

    def stderr
      @childprocess.io.stderr
    end

    def puts(str)
      @childprocess.io.stdin.puts "#{str}"
    end

    def wait
      @childprocess.wait
    end

    private

    def build_childprocess
      proc = ChildProcess.build("bash", "-l", "-O", "expand_aliases")
      proc.duplex = true
      proc.io.stdout = proc.io.stderr = @w
      proc
    end
  end

  class Console
    attr_reader :world

    def initialize(io_in:$stdin, prompt:"> ")
      @io_in = io_in
      @prompt = prompt
      @world = World.new(prompt: prompt)
    end

    def preload_shells(n=1)
      @shells ||= n.times.map{ Shell.new }
    end

    def parse_commands(line)
      scope = []
      words = []
      str = ''

      line.each_char.with_index do |ch, i|
        popped = false
        if scope.last == ch
          scope.pop
          popped = true
        end

        if (scope.empty? && ch == "|") || (i == line.length - 1)
          str << ch unless ch == "|"
          words << str.strip
          str = ''
        else
          if %w(' ").include?(ch) && !popped
            scope << ch
          end
          str << ch
        end
      end
      words.map { |f| f[0] == "!" ? [f] : f.shellsplit }
    end

    def run
      preload_shells

      at_exit do
        Dir["fifo-test-*"].each do |f|
          (FileUtils.rm f rescue nil)
        end
      end

      STDOUT.sync = true

      loop do
        line = Readline.readline("#{world.prompt}", true)
        line.strip!
        next if line == ""

        if line =~ /^!(.*)/ || line =~ /^(\w+)!/
          command = $1

          if command == "reload"
            break
          else
            world.instance_eval command
          end

          next
        end

        commands = parse_commands(line)
        pipes = []

        shell = @shells.first
        shell.open_pty
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
            File.mkfifo pipe_in
            command << " < #{pipe_in}"
          end

          if pipe_out.is_a?(String)
            unless File.exists?(pipe_out)
              puts "Pipe: #{pipe_out}" if ENV["DEBUG"]
              File.mkfifo pipe_out
            end
            command << " > #{pipe_out}"
          elsif pipe_out.is_a?(IO)
            puts "IO Pipe: #{pipe_out}" if ENV["DEBUG"]
            command << " > #{pipe_out.path}"
          end

          if ruby_command
            puts "ruby: #{ruby_command}" if ENV["DEBUG"]
            fork {
              f = File.open(pipe_in)
              contents = f.readpartial(8192)
              str = contents.send :eval, ruby_command
              f.close

              f2 = File.open(pipe_out, "w")
              f2.write str
              f2.close

              exit!
            }

          elsif pipe_in and pipe_out
            command << " &"
          end

          unless ruby_command
            puts command if ENV["DEBUG"]
          end

          puts if ENV["DEBUG"]

          shell.puts command unless ruby_command
          command
        end

        pid = fork {
            puts shell.pty_master.readpartial(10_000)
            # puts "no master"
            # f3 = File.open(pipes.first.pipe_out)
            # puts str = f3.read
            # f3.close
          # end
        }

        Process.wait pid
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
