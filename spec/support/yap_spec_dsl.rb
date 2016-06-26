require 'fileutils'
require 'pathname'
require 'timeout'
require 'ostruct'

module Yap
  module Spec
    class OutputFile
      def initialize(filepath)
        @filepath = filepath
      end

      def clear
        `> #{@filepath}`
      end

      def read
        file = File.open(@filepath, 'rb')
        file.read.gsub(/\u0000/, '')
      end
    end

    class Shell
      def self.current
        @instance
      end

      def self.new(**kwargs)
        if @instance
          @instance.stop
        end
        @instance = allocate.tap do |instance|
          instance.send :initialize, **kwargs
          instance.start
        end
      end

      def initialize(dir:, args:, stdout:, stderr:)
        @childprocess = nil
        @dir = dir
        @args = args
        @stdout = stdout
        @stderr = stderr
      end

      def io
        @childprocess.io if @childprocess
      end

      def stop
        if @childprocess
          @childprocess.stop
          @childprocess.wait
        end
      end

      def start
        return @childprocess if @childprocess
        @childprocess = begin
          process = ChildProcess.build(
            'ruby',
            @dir,
            *@args
          )

          process.io.stdout = @stdout
          process.io.stderr = @stderr

          # make stdin available, writable
          process.duplex = true

          process.cwd = Dir.pwd
          process.start

          # make sure clean-up child processes, hang if any fail
          # to stop
          at_exit do
            process.stop
            process.wait
          end

          process
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
        mkdir_p path
      end

      def mkdir_p(path)
        unless File.expand_path(path.to_s).include?(tmp_dir.to_s)
          path = tmp_dir.join(path)
        end
        FileUtils.mkdir_p Pathname.new(path).expand_path
      end

      def chdir(path, &blk)
        Dir.chdir(path, &blk)
      end

      def rmdir(path)
        path = tmp_dir.join(path) unless path == tmp_dir
        FileUtils.rm_rf Pathname.new(path).expand_path
      end

      def write_file(filename, contents)
        filename = tmp_dir.join(filename) unless filename.to_s.include?(tmp_dir.to_s)
        file = File.new(filename, 'w+')
        file.write contents
        file.close
      end

      def write_executable_script(filename, contents)
        filename = tmp_dir.join(filename) unless filename.to_s.include?(tmp_dir.to_s)
        file = File.new(filename, 'w+')
        file.write contents
        file.chmod 0755
        file.close
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
      end

      def set_yap_command_line_arguments(*args)
        @yap_command_line_arguments = args.flatten
      end

      def yap_command_line_arguments
        @yap_command_line_arguments
      end

      def initialize_shell
        Shell.new(
          dir: yap_dir.join('bin/yap-dev').to_s,
          args: yap_command_line_arguments,
          stdout: stdout,
          stderr: stderr
        )
      end

      def reinitialize_shell
        initialize_shell
      end

      def shell
        Shell.current
      end

      def set_prompt(str)
        shell.io.stdin.print "!prompt = '#{str}'"
        enter
      end

      def typed_content_awaiting_enter?
        @typed_content_awaiting_enter
      end

      def type(str)
        @typed_content_awaiting_enter = true
        shell.io.stdin.print str
      end

      def enter
        @typed_content_awaiting_enter = false
        shell.io.stdin.print "\r"
      end

      def clear_all_output
        output_file.clear
        error_output_file.clear
      end

      def output
        str = ANSIString.new output_file.read
        without_ansi_str = str.without_ansi.force_encoding(
          Encoding::ASCII_8BIT
        ).gsub(/(\x9B|\x1B\[)[0-?]*[ -\/]*[@-~]/n, '')
      end

      def error_output
        str = ANSIString.new error_output_file.read
        str.without_ansi.force_encoding(
          Encoding::ASCII_8BIT
        ).gsub(/(\x9B|\x1B\[)[0-?]*[ -\/]*[@-~]/n, '')
      end

      def output_file
        @output_file ||= OutputFile.new(stdout.path)
      end

      def error_output_file
        @error_output_file ||= OutputFile.new(stderr.path)
      end

      def stdout
        yap_dir
        @stdout ||= begin
          File.open yap_dir.join('stdout.log').expand_path, 'wb'
        end
        @stdout.sync = true
        @stdout
      end

      def stderr
        @stderr ||= begin
          File.open yap_dir.join('stderr.log').expand_path, 'wb'
        end
        @stderr.sync = true
        @stderr
      end

      def timeout
        @timeout ||= 2 # seconds
      end
    end
  end
end
