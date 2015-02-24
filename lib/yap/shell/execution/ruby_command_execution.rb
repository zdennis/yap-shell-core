module Yap::Shell::Execution
  class RubyCommandExecution < CommandExecution
    on_execute do |command:, n:, of:|
      result = nil
      stdin, stdout, stderr, world = @stdin, @stdout, @stderr, @world
      t = Thread.new {
        exit_code = 0
        first_command = n == 1

        f = nil
        ruby_result = nil
        begin
          ruby_command = command.to_executable_str

          contents = if stdin.is_a?(String)
            puts "READ: stdin as a String: #{stdin.inspect}" if ENV["DEBUG"]
            f = File.open stdin
            f.read
          elsif stdin != $stdin
            puts "READ: stdin is not $stdin: #{stdin.inspect}" if ENV["DEBUG"]
            stdin.read
          else
            puts "READ: contents is: #{contents.inspect}" if ENV["DEBUG"]
          end

          puts "READ: #{contents.length} bytes from #{stdin}" if ENV["DEBUG"] && contents
          world.contents = contents

          method = ruby_command.scan(/^(\w+(?:[!?]|\s*=)?)/).flatten.first.gsub(/\s/, '')
          puts "method: #{method}" if ENV["DEBUG"]

          obj = if first_command
            world
          elsif contents.respond_to?(method)
            contents
          else
            world
          end

          if ruby_command =~ /^[A-Z0-9]|::/
            puts "Evaluating #{ruby_command.inspect} globally" if ENV["DEBUG"]
            ruby_result = eval ruby_command
          else
            ruby_command = "self.#{ruby_command}"
            puts "Evaluating #{ruby_command.inspect} on #{obj.inspect}" if ENV["DEBUG"]
            ruby_result = obj.instance_eval ruby_command
          end
        rescue Exception => ex
          ruby_result = <<-EOT.gsub(/^\s*\S/, '')
            |Failed processing ruby: #{ruby_command}
            |#{ex}
            |#{ex.backtrace.join("\n")}
          EOT
          exit_code = 1
        ensure
          f.close if f && !f.closed?
        end

        # The next line  causes issues sometimes?
        # puts "WRITING #{ruby_result.length} bytes" if ENV["DEBUG"]
        ruby_result = ruby_result.to_s
        ruby_result << "\n" unless ruby_result.end_with?("\n")

        stdout.write ruby_result
        stdout.flush
        stderr.flush

        stdout.close if stdout != $stdout && !stdout.closed?
        stderr.close if stderr != $stderr && !stderr.closed?

        # Pass current execution to give any other threads a chance
        # to be scheduled before we send back our status code. This could
        # probably use a more elaborate signal or message passing scheme,
        # but that's for another day.
        Thread.pass

        # Make up an exit code
        result = Result.new(status_code:exit_code, directory:Dir.pwd, n:n, of:of)
      }
      t.abort_on_exception = true
      t.join
      result
    end
  end
end
