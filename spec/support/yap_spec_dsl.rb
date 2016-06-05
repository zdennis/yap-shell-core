require 'fileutils'
require 'pathname'
require 'timeout'

module Yap
  module Spec
    class OutputFile
      def initialize(filepath)
        @filepath = filepath
        @bytes_read = 0
      end

      def read
        file = File.open(@filepath, 'rb')
        file.seek(@bytes_read)
        file.read.tap do |str|
          @bytes_read += str.bytes.length
        end
      end
    end

    module DSL
      def very_soon(timeout: self.timeout, &block)
        @wait_for_last_exception = nil
        begin
          Timeout.timeout(timeout) do
            begin
              block.call
            rescue RSpec::Expectations::ExpectationNotMetError => ex
              @wait_for_last_exception = ex
              sleep 0.1
              retry
            end
          end
        rescue Timeout::Error
          raise @wait_for_last_exception
        rescue Exception => ex
          raise ex
        end
      end

      def touch(path)
        FileUtils.touch path
      end

      def mkdir(path)
        path = tmp_dir.join(path) unless path == tmp_dir
        FileUtils.mkdir_p Pathname.new(path).expand_path
      end

      def chdir(path, &blk)
        Dir.chdir(path, &blk)
      end

      def rmdir(path)
        path = tmp_dir.join(path) unless path == tmp_dir
        FileUtils.rm_rf Pathname.new(path).expand_path
      end

      def tmp_dir
        yap_dir.join('tmp/specroot').expand_path
      end

      def yap_dir
        Pathname.new File.dirname(__FILE__) + '/../../'
      end

      def turn_on_debug_log(file: '/tmp/yap-debug.log', debug: '*')
        ENV['TREEFELL_OUT'] = file
        ENV['DEBUG'] = debug
        reinitialize_shell
      end

      def set_yap_command_line_arguments(*args)
        @yap_command_line_arguments = args
      end

      def yap_command_line_arguments
        @yap_command_line_arguments
      end

      def initialize_shell
        @shell.stop if @shell
        begin
          process = ChildProcess.build(
            'ruby',
            yap_dir.join('bin/yap-dev').to_s,
            *yap_command_line_arguments
          )

          process.io.stdout = stdout
          process.io.stderr = stderr

          # make stdin available, writable
          process.duplex = true

          # tmpdir = File.dirname(__FILE__) + '/../tmp'
          process.cwd = File.dirname(__FILE__)
          process.start
          process
        end
      end
      alias_method :reinitialize_shell, :initialize_shell

      def shell
        @shell ||= reinitialize_shell
      end

      def set_prompt(str)
        shell.io.stdin.print "!prompt = '#{str}'"
        enter
      end

      def type(str)
        shell.io.stdin.print str
      end

      def enter
        shell.io.stdin.print "\r"
      end

      def output
        str = ANSIString.new output_file.read
        str.without_ansi.force_encoding(
          Encoding::ASCII_8BIT
        ).gsub(/(\x9B|\x1B\[)[0-?]*[ -\/]*[@-~]/n, '')
      end

      def output_file
        @output_file ||= OutputFile.new(stdout.path)
      end

      def stdout
        @stdout ||= File.open(File.expand_path('stdout.log'), 'wb')
        @stdout.sync = true
        @stdout
      end

      def stderr
        @stderr ||= File.new(File.expand_path('stderr.log'), 'wb')
        @stderr.sync = true
        @stderr
      end

      def timeout
        @timeout ||= 2 # seconds
      end
    end
  end
end
