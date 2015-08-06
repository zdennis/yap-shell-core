require 'yap/shell/aliases'
require 'shellwords'

module Yap::Shell
  module Builtins
    builtin :alias do |args:, stdout:, **kwargs|
      output = []
      if args.empty?
        Yap::Shell::Aliases.instance.to_h.each_pair do |name, value|
          # Escape and wrap single quotes since we're using
          # single quotes to wrap the aliased command for matching
          # bash output.
          escaped_value = value.gsub(/'/){ |a| "'\\#{a}'" }
          output << "alias #{name.shellescape}='#{escaped_value}'"
        end
        output << ""
      else
        name_eq_value = args.first
        name, command = name_eq_value.scan(/^(.*?)\s*=\s*(.*)$/).flatten
        Yap::Shell::Aliases.instance.set_alias name, command
      end
      stdout.puts output.join("\n")
    end
  end
end
