module Yap::Shell
  module Builtins

    builtin :env do |world:, args:, stdout:, **|
      world.env.keys.sort.each do |key|
        stdout.puts "#{key}=#{world.env[key]}"
      end
    end

  end
end
