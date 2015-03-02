module Yap::Shell
  module Builtins
    DIRECTORY_HISTORY = []
    DIRECTORY_FUTURE  = []

    builtin :cd do |path=ENV['HOME'], *_|
      DIRECTORY_HISTORY << Dir.pwd
      Dir.chdir(path)
      ENV["PWD"] = Dir.pwd
      output=""
    end

    builtin :popd do
      output = []
      if DIRECTORY_HISTORY.any?
        DIRECTORY_FUTURE << Dir.pwd
        path = DIRECTORY_HISTORY.pop
        execute_builtin :cd, path
      else
        output << "popd: directory stack empty\n"
      end
      output.join("\n")
    end

    builtin :pushd do
      output = []
      if DIRECTORY_FUTURE.any?
        DIRECTORY_HISTORY << Dir.pwd
        path = DIRECTORY_FUTURE.pop
        execute_builtin :cd, path
      else
        output << "pushd: there are no directories in your future\n"
      end
      output.join("\n")
    end
  end
end
