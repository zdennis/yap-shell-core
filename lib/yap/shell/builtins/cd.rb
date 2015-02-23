module Yap::Shell
  module Builtins
    DIRECTORY_HISTORY = []

    builtin :cd do |path=ENV['HOME'], *_|
      DIRECTORY_HISTORY << Dir.pwd
      Dir.chdir(path)
      ENV["PWD"] = Dir.pwd
      output=""
    end

    builtin :popd do
      output = []
      if DIRECTORY_HISTORY.any?
        Dir.chdir(DIRECTORY_HISTORY.pop)
      else
        output << "popd: directory stack empty\n"
      end
      output.join("\n")
    end
  end
end
