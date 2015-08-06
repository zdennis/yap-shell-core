module Yap::Shell
  module Builtins
    DIRECTORY_HISTORY = []
    DIRECTORY_FUTURE  = []

    builtin :cd do |world:, args:, stderr:, **|
      path = args.first || world.env['HOME']
      if Dir.exist?(path)
        DIRECTORY_HISTORY << Dir.pwd
        world.env["PWD"] = File.expand_path(path)
        Dir.chdir(path)
        exit_status = 0
      else
        stderr.puts "cd: #{path}: No such file or directory"
        exit_status = 1
      end
    end

    builtin :popd do |world:, args:, stderr:, **keyword_args|
      output = []
      if DIRECTORY_HISTORY.any?
        path = DIRECTORY_HISTORY.pop
        if Dir.exist?(path)
          DIRECTORY_FUTURE << Dir.pwd
          Dir.chdir(path)
          world.env["PWD"] = Dir.pwd
          exit_status = 0
        else
          stderr.puts "popd: #{path}: No such file or directory"
          exit_status = 1
        end
      else
        stderr.puts "popd: directory stack empty"
        exit_status = 1
      end
    end

    builtin :pushd do |world:, args:, stderr:, **keyword_args|
      output = []
      if DIRECTORY_FUTURE.any?
        path = DIRECTORY_FUTURE.pop
        if Dir.exist?(path)
          DIRECTORY_HISTORY << Dir.pwd
          Dir.chdir(path)
          world.env["PWD"] = Dir.pwd
          exit_status = 0
        else
          stderr.puts "pushd: #{path}: No such file or directory"
          exit_status = 1
        end
      else
        stderr.puts "pushd: there are no directories in your future"
        exit_status = 1
      end
    end
  end
end
