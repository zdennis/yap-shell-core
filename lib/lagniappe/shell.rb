require 'shellwords'
require 'readline'
require 'term/ansicolor'

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
    def initialize
      @r, @w = IO.pipe
      @childprocess = build_childprocess
      @childprocess.start
      @available = true
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
      @childprocess.io.stdin.puts "#{str} && echo ."

      data = @r.readpartial 1
      loop do
        max_retry = 5
        tries = 1
        begin
          data << @r.read_nonblock(8192)
        rescue Errno::EWOULDBLOCK => ex
          if ((tries+=1) < max_retry)
            sleep 0.1
            retry
          else
            break
          end
        end
      end

      data = data[0..-3]
      data
    end

    def wait
      @childprocess.wait
    end

    private

    def build_childprocess
      proc = ChildProcess.build("bash", "-l", "-O", "expand_aliases")
      # enable read/write
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

    def run
      preload_shells

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

        commands = split_on_pipes(line)

        placeholder_in = $stdin
        placeholder_out = $stdout
        pipe = []

        shell = @shells.first
        commands.each_with_index do |command, index|
          program, *arguments = command
          program = program.shellescape
          arguments.shelljoin.gsub! "\\$", "$"

          if builtin?(program)
            call_builtin(program, *arguments)

          else
            if index+1 < commands.size
              pipe = IO.pipe
              placeholder_out = pipe.last
            else
              placeholder_out = $stdout
            end

            spawn_program(shell, program, *arguments, placeholder_out, placeholder_in)

            placeholder_out.close unless placeholder_out == $stdout
            placeholder_in.close unless placeholder_in == $stdin
            placeholder_in = pipe.first
          end
        end
      end
    end

    private

    def builtin?(program)
      builtins.has_key?(program)
    end

    def spawn_program(shell, program, *arguments, placeholder_out, placeholder_in)
      puts "Spawning: #{program.inspect} #{arguments.inspect}" #if ENV["DEBUG"]
      if $stdin != placeholder_in
        f = Tempfile.new "foo"
        s = placeholder_in.read
        f.write s
        f.close
        placeholder_out.write shell.puts("#{program} #{arguments.join(' ')} < #{f.path}")
      else
        placeholder_out.write shell.puts("#{program} #{arguments.join(' ')}")
      end
      # fork {
      #   unless placeholder_out == $stdout
      #     $stdout.reopen(placeholder_out)
      #     placeholder_out.close
      #   end
      #
      #   unless placeholder_in == $stdin
      #     $stdin.reopen(placeholder_in)
      #     placeholder_in.close
      #   end
      #
      #   # puts program.inspect
      #   # puts '-', arguments.inspect
      #   #cmd = %|bash -ic "source ~/.bashrc &&  shopt -s expand_aliases && #{program} #{arguments.join(' ')}"|
      #   # puts cmd
      #   puts shell.puts "#{program} #{arguments.join(' ')}"
      #   exit 0
      # }
      # shell
    end

    def split_on_pipes(line)
      Shellwords.split(line).reduce([[]]) do |acc,n|
        if n == "|" then
          acc << []
        else
          acc.last << n.strip
        end
        acc
      end
      #
      # line.scan( /([^"'|]+)|["']([^"']*)["']/ ).flatten.compact
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
