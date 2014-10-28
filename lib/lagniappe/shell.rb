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
      @r, @w = IO.pipe
      @childprocess = ChildProcess.build("bash", "-l", "-O", "expand_aliases")
      @childprocess.duplex = true
      @childprocess.io.stdout = @childprocess.io.stderr = @w
      @childprocess.start
      @childprocess
    end
  end
end
