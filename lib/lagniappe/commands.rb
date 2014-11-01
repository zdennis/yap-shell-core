require 'ostruct'

module Lagniappe
  class CommandFactory
    def self.build_command_for(command_str)
      case command_str
      when /^\!/ then RubyCommand.new(str:command_str)
      else            ShellCommand.new(str:command_str)
      end
    end
  end

  class CommandChain < Array
  end

  class CommandPipeline
    def initialize(shell:,commands:)
      @shell = shell
      @commands = commands
      @pipes = []
    end

    def length
      @commands.length
    end

    def each(&blk)
      @pipes.clear
      arr = @commands.map.with_index do |command, n|
        stdin, stdout, stderr = fds_for_command n:n+1, of: @commands.length
        @pipes << OpenStruct.new(stdin:stdin, stdout:stdout, stderr:stderr)
        [command, stdin, stdout, stderr]
      end
      if block_given?
        arr.each{ |*args| yield *args }
      else
        arr.each
      end
    end

    private

    # grep  < test-3 > /ttys    n:1  of:4   input: of - n = "3"
    # cat   < test-2 > test-3   n:2  of:4   input: of - n = "2"  output: n = "3"
    # grep  < test-1 > test-2   n:3  of:4   input: of - n = "1"  output: n = "2"
    # ls             > test-1   n:4  of:4                        output: n = "1"

    def fds_for_command(n:, of:)
      if of == 1    # only one command in the pipeline
        [nil, @shell.pty_slave.path, @shell.pty_slave.path]
      elsif n == 1  # we are the last command, e.g. 'grep' in 'ls | grep e'
        ["fifo-test-#{of - n}", @shell.pty_slave.path, @shell.pty_slave.path]
      elsif n == of # we are the first command, e.g. 'ls' in 'ls | grep e'
        [nil, @pipes.last.stdin, @pipes.last.stdin]
      elsif n < of  # more than one command in the pipeline, w're somewhere in the middle
        ["fifo-test-#{of - n}", @pipes.last.stdin, @pipes.last.stdin]
      end
    end
  end

  # pipe_out, pipe_in = if last_item
  #   [shell.pty_slave.path, shell.pty_master]
  # elsif last_item
  #   [pipes.last.pipe_in, nil]
  # elsif i == 0
  #   [shell.pty_slave.path, "fifo-test-#{i*2+1}"]
  # else
  #   [pipes.last.pipe_in, "fifo-test-#{i+1}"]
  # end
  # pipes << OpenStruct.new(pipe_in: pipe_in, pipe_out: pipe_out)
  # puts pipes.last.inspect if ENV["DEBUG"]
  #
  # if pipe_in && !last_item
  #   puts "Pipe: #{pipe_in}" if ENV["DEBUG"]
  #   File.mkfifo pipe_in unless File.exists?(pipe_in)
  #   command_str << " < #{pipe_in}"
  # end
  #
  # if pipe_out.is_a?(String)
  #   unless File.exists?(pipe_out)
  #     puts "Pipe: #{pipe_out}" if ENV["DEBUG"]
  #     File.mkfifo pipe_out  unless File.exists?(pipe_out)
  #   end
  #   command_str << " > #{pipe_out}"
  # elsif pipe_out.is_a?(IO)
  #   puts "IO Pipe: #{pipe_out}" if ENV["DEBUG"]
  #   command_str << " > #{pipe_out.path}"
  # end


  module Command
    attr_reader :str

    def initialize(str: str)
      @str = str
    end

    def execute_in
      raise NotImplementedError, ":execute_in must be implemented by including object."
    end
  end

  class ShellCommand
    include Command

    def prepare(shell:,stdin:,stdout:,stderr:)
      cmd = "#{to_executable_str}"
      cmd << " < #{stdin}" if stdin
      cmd << " > #{stdout}" if stdout
      cmd
    end

    def to_executable_str
      str.shellsplit.flatten.join " "
    end
  end

  class RubyCommand
    include Command

    def execute(shell:,stdin:,stdout:,stderr:)
      puts "IGNORING RUBY"
    end

    def to_executable_str(stdin:,stdout:,stderr:)
      str
    end
  end
end
