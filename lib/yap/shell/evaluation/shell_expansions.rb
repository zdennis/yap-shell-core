module Yap::Shell
  class Evaluation
    class ShellExpansions
      attr_reader :aliases, :world

      def initialize(world:, aliases: Aliases.instance)
        @world = world
        @aliases = aliases
      end

      def expand_aliases_in(input)
        Treefell['shell'].puts "shell-expansions expand aliases in: #{input.inspect}"
        head, *tail = input.split(/\s/, 2).first
        expanded = if aliases.has_key?(head)
          new_head=aliases.fetch_alias(head)
          [new_head].concat(tail).join(" ")
        else
          input
        end
        expanded
      end

      def expand_words_in(input, escape_directory_expansions: true)
        Treefell['shell'].puts "shell-expansions expand words in: #{input.inspect}"
        expanded = [input].flatten.inject([]) do |results,str|
          results << process_expansions(
            word_expand(str),
            escape_directory_expansions: escape_directory_expansions
          )
        end.flatten
        expanded
      end

      def expand_variables_in(input)
        Treefell['shell'].puts "shell-expansions expand variables in: #{input.inspect}"
        env_expand(input)
      end

      private

      def env_expand(str)
        # match "$a", "$a $b", "$a$b", "$cat$dog $foo"
        str.gsub(/\$([^\$\s]+)/) do |match,*args|
          var_name = match[1..-1]
          if var_name == '?'
            (world.last_result ? world.last_result.status_code.to_s : '0').tap do |expanded|
              Treefell['shell'].puts "shell-expansions expanding env var #{match} to #{expanded}"
            end
          elsif world.env.has_key?(var_name)
            world.env.fetch(var_name).tap do |expanded|
              Treefell['shell'].puts "shell-expansions expanding env var #{match} to #{expanded}"
            end
          else
            match
          end
        end
      end

      def word_expand(str)
        content = str.scan(/\{([^\}]+)\}/).flatten.first
        if content
          expansions = content.split(",", -1)

          # Break compatibility with Bash/Zsh. They do not expand words
          # when there is only one word supplied (e.g. "a_{word}"), but this
          # is counter-intuitive to me. It should behave the same regardless
          # of the number of words provided to expand.
          expanded = expansions.map { |expansion| str.sub(/\{([^\}]+)\}/, expansion) }.tap do |expanded|
            Treefell['shell'].puts "shell-expansions expanding words in #{str} to #{expanded}"
          end
        else
          [str]
        end
      end

      def process_expansions(expansions, escape_directory_expansions: true)
        expansions.map do |s|
          # Basic bash-style tilde expansion
          s.gsub!(/\A~(.*)/, world.env["HOME"] + '\1')

          # Basic bash-style variable expansion
          s = env_expand(s)

          # Basic bash-style path-name expansion
          expansions = Dir[s]
          if expansions.any?
            if escape_directory_expansions
              expansions.map(&:shellescape)
            else
              expansions
            end
          else
            s
          end
        end.flatten
      end
    end
  end
end
