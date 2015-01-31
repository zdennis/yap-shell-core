require 'shellwords'
require 'readline'

require 'mkfifo'
require 'ostruct'
require 'pty'

module Lagniappe
  require 'childprocess'
  class Shell
    attr_reader :pty_master, :pty_slave

    def initialize
      build_childprocess
    end

    def open_pty
      @pty_master.close if @pty_master
      @pty_slave.close  if @pty_slave
      @pty_master, @pty_slave = PTY.open
      @pty_master.sync = true
      @pty_slave.sync = true
    end

    def stdin
      @w
    end

    def stdout
      @r
    end

    def stderr
      @r
    end

    # Sends a INT signal to the child process of our child process.
    # Killing the child process itself will result in pipe errors. 
    def interrupt!
      pids = `ps -o pid -g #{@childprocess.pid}`.split("\n")
      pid = pids[-1]
      $stdout.puts "Killing: #{pid}" if ENV["DEBUG"]
      `kill -INT #{pid}`
    end

    def puts(str)
      @childprocess.io.stdin.puts "#{str}"
    end

    def wait
      @childprocess.wait
    end

    private

    def build_childprocess
      @r, @w = IO.pipe
      @r.sync = true
      @w.sync = true
      @childprocess = ChildProcess.build("bash", "-l", "-O", "expand_aliases")
      @childprocess.duplex = true
      @childprocess.io.stdout = @childprocess.io.stderr = @w
      @childprocess.leader = true
      @childprocess.start
      @childprocess
    end
  end
end
