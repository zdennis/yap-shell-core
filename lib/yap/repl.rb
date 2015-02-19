require 'shellwords'
require 'terminfo'
$LOAD_PATH.unshift File.dirname(__FILE__) + "/../../../yap-shell-line-parser/lib"
require 'yap/line/parser'
require 'yap/line/my_parser'

module Yap
  class Repl
    def initialize(world:)
      @world = world
    end

    require 'terminfo'
    include Term::ANSIColor

    def clear_time
      time_str = Time.now.strftime("%H:%M:%S")
      time_str_without_ansii = time_str.gsub(/\x1b[^m]*m/, '')
      h, w = t.screen_size
      t.control "sc"
      t.control "cub", w
      t.control "cuf", w - time_str_without_ansii.length
      t.write black(" " * time_str_without_ansii.length)
      t.control "rc"
    end

    def print_time(on:)
      # t.control "cud", 1
      time_str = Time.now.strftime("%H:%M:%S")
      time_str_without_ansii = time_str.gsub(/\x1b[^m]*m/, '')
      h, w = t.screen_size
      t.control "sc"
      t.control "cub", w
      if on == :previous_row
        t.control "cuu", 1
      end
      t.control "cuf", w - time_str_without_ansii.length
      t.write bright_black(time_str)
      t.control "rc"
    end

    attr_reader :t
    def loop_on_input(&blk)
      @blk = blk
      @t = TermInfo.new("xterm-256color", STDOUT)
      @stdin = $stdin
      @stdout = $stdout
      @stderr = $stderr
f = File.open("/tmp/z.log", "w+")
      loop do
        # t.control "clear"
        # t.control "cwin", 0, 0, 100, 100

        heredoc = nil
        prompt = ""
        without_ansii_proc = ->(str){ str.gsub(/\x1b[^m]*m/, '') }
        prompt_without_ansii = ""


        begin
          thr = Thread.new do
            loop do
              rows, columns = t.screen_size
              prompt_without_ansii = without_ansii_proc.call(prompt)
              time_str = Time.now.strftime("%H:%M:%S")
              time_str_without_ansii = without_ansii_proc.call(time_str)
              used_columns = Readline.line_buffer.to_s.length + prompt_without_ansii.length + time_str_without_ansii.length
f.puts "Used: #{used_columns} Columns: #{columns}"
f.flush
              if used_columns == columns
                clear_time
              elsif used_columns < columns
                print_time on: :current_row
              end
              sleep 0.1
            end
          end
          thr.abort_on_exception = true

          prompt = @world.prompt
          # prompt = "foobar >"
          prompt_without_ansii = without_ansii_proc.call(prompt)
          rows, columns = t.screen_size

          # time_str = Time.now.strftime("%H:%M:%S")
          # time_str_without_ansii = time_str.gsub(/\x1b[^m]*m/, '')
          #
          # Signal.trap("WINCH") do
          #   rows, columns = t.screen_size
          #   # puts "WINCH: rows: #{rows}  columns: #{columns}  #{columns - (prompt_without_ansii.length + time_str_without_ansii.length)}"
          #   ncols = columns - (time_str_without_ansii.length)
          #   Readline.set_screen_size(rows, ncols)
          # end
          #
          # ncols = columns - (time_str_without_ansii.length)
          # Readline.set_screen_size(rows, columns - 10)
          input = Readline.readline("#{prompt}", true)
          Thread.kill(thr)

          print_time on: :previous_row
          next if input == ""

          input = process_heredoc(input)

          ast = Yap::Line::MyParser.new.parse(input)
          ast.accept self
        rescue ::Yap::CommandUnknownError => ex
          puts "  CommandError: #{ex.message}"
        rescue Interrupt
          puts "^C"
          next
        rescue SuspendSignalError
          # no-op since if we got here we're on the already at the top-level
          # repl and there's nothing to suspend but ourself and we're not
          # about to do that.
          puts "^Z"
          next
        ensure
          thr.kill if thr
        end

      end
    end

    def with_standard_streams(&blk)
      stdin, stdout, stderr = @stdin, @stdout, @stderr
      yield stdin, stdout, stderr
      @stdin, @stdout, @stderr = stdin, stdout, stderr
    end

    def stream_redirections_for(node)
      stdin, stdout, stderr = @stdin, @stdout, @stderr
      node.redirects.each do |redirect|
        case redirect.kind
        when "<"
          stdin = redirect.target
        when ">", "1>"
          stdout = redirect.target
        when "1>&2"
          stderr = :stdout
        when "2>"
          stderr = redirect.target
        when "2>&1"
          stdout = :stderr
        end
      end
      [stdin, stdout, stderr]
    end

    def visit_CommandNode(node)
      @aliases_expanded ||= []
      with_standard_streams do |stdin, stdout, stderr|
        if !@aliases_expanded.include?(node.command) && _alias=Aliases.instance.fetch_alias(node.command)
          @suppress_events = true
          ast = Yap::Line::MyParser.new.parse([_alias].concat(node.args).join(" "))
          @aliases_expanded.push(node.command)
          ast.accept(self)
          @aliases_expanded.pop
          @suppress_events = false
        else
          command = CommandFactory.build_command_for(
            command: node.command,
            args:    shell_expand(node.args),
            heredoc: node.heredoc,
            internally_evaluate: node.internally_evaluate?)
          @stdin, @stdout, @stderr = stream_redirections_for(node)
          @last_result = @blk.call command, @stdin, @stdout, @stderr
        end
      end
    end

    def visit_StatementsNode(node)
      env = ENV.to_h
      Yap::ExecutionContext.fire :before_statements_execute, self unless @suppress_events
      node.head.accept(self)
      if node.tail
        node.tail.accept(self)
        ENV.clear
        ENV.replace(env)
      end
      Yap::ExecutionContext.fire :after_statements_execute, self unless @suppress_events
    end

    def visit_EnvWrapperNode(node)
      env = ENV.to_h
      node.env.each_pair do |k,v|
        ENV[k] = v
      end
      node.node.accept(self)
      ENV.clear
      ENV.replace(env)
    end

    def visit_EnvNode(node)
      node.env.each_pair do |key,val|
        ENV[key] = val
      end
    end

    def visit_ConditionalNode(node)
      case node.operator
      when '&&'
        node.expr1.accept self
        if @last_result.status_code == 0
          node.expr2.accept self
        end
      when '||'
        node.expr1.accept self
        if @last_result.status_code != 0
          node.expr2.accept self
        end
      else
        raise "Don't know how to visit conditional node: #{node.inspect}"
      end
    end

    def visit_PipelineNode(node, options={})
      with_standard_streams do |stdin, stdout, stderr|
        # Modify @stdout and @stderr for the first command
        stdin, @stdout = IO.pipe
        @stderr = @stdout

        # Don't modify @stdin for the first command in the pipeline.
        node.head.accept(self)

        # Modify @stdin starting with the second command to read from the
        # read portion of our above stdout.
        @stdin = stdin

        # Modify @stdout,@stderr to go back to the original
        @stdout, @stderr = stdout, stderr

        node.tail.accept(self)

        # Set our @stdin back to the original
        @stdin = stdin
      end
    end

    def visit_InternalEvalNode(node)
      command = CommandFactory.build_command_for(
        command: node.command,
        args:    node.args,
        heredoc: node.heredoc,
        internally_evaluate: node.internally_evaluate?)
      @last_result = @blk.call command, @stdin, @stdout, @stderr
    end

    private

    def alias_expand(input, aliases:Aliases.instance)
      head, *tail = input.split(/\s/, 2).first
      if new_head=aliases.fetch_alias(head)
        [new_head].concat(tail).join(" ")
      else
        input
      end
    end

    def shell_expand(input)
      [input].flatten.map do |str|
        str.gsub!(/\A~(.*)/, ENV["HOME"] + '\1')
        if str =~ /^\$(.*)/
          str = ENV.fetch($1, "")
        end
        expanded = Dir[str]
        expanded.any? ? expanded : str
      end.flatten
    end

    def process_heredoc(_input)
      if _input =~ /<<-?([A-z0-9\-]+)\s*$/
        input = _input.dup
        marker = $1
        input << "\n"
      else
        return _input
      end

      puts "Beginning heredoc" if ENV["DEBUG"]
      loop do
        str = Readline.readline("> ", true)
        input << "#{str}\n"
        if str =~ /^#{Regexp.escape(marker)}$/
          puts "Ending heredoc" if ENV["DEBUG"]
          break
        end
      end
      input
    end

  end
end
