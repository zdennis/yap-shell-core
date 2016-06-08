require 'shellwords'

module Yap::Shell
  require 'yap/shell/aliases'

  module Builtins
    Color = ::Term::ANSIColor

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
        name_eq_value = args.map(&:shellsplit).join(' ')
        name, command = name_eq_value.scan(/^(.*?)\s*=\s*(.*)$/).flatten
        output << "Setting alias #{name} #{Color.green('done')}"
        Yap::Shell::Aliases.instance.set_alias name, command
      end
      stdout.puts output.join("\n")
    end

    builtin :unalias do |args:, stdout:, **kwargs|
      output = []
      if args.empty?
        output << "Usage: unalias <aliasname>"
      else
        args.each do |alias_name|
          Yap::Shell::Aliases.instance.unset_alias alias_name
          output << "Removing alias #{alias_name} #{Color.green('done')}"
        end
      end
      stdout.puts output.join("\n")
    end
  end
end
