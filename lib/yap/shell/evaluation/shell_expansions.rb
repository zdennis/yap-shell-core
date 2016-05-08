module Yap::Shell
  class Evaluation
    class ShellExpansions
      attr_reader :aliases, :world

      def initialize(world:, aliases: Aliases.instance)
        @world = world
        @aliases = aliases
      end

      def expand_aliases_in(input)
        head, *tail = input.split(/\s/, 2).first
        if aliases.has_key?(head)
          new_head=aliases.fetch_alias(head)
          [new_head].concat(tail).join(" ")
        else
          input
        end
      end

      def expand_words_in(input, escape_directory_expansions: true)
        [input].flatten.inject([]) do |results,str|
          results << process_expansions(
            word_expand(str),
            escape_directory_expansions: escape_directory_expansions
          )
        end.flatten
      end

      def expand_variables_in(input)
        env_expand(input)
      end

      private

      def env_expand(str)
        str.gsub(/\$(\S+)/) do |match,*args|
          var_name = match[1..-1]
          case var_name
          when "?"
            world.last_result ? world.last_result.status_code.to_s : '0'
          else
            world.env.fetch(var_name){ match }
          end
        end
      end

      def word_expand(str)
        content = str.scan(/\{([^\}]+)\}/).flatten.first
        if content
          expansions = content.split(",", -1)

          # Be compatible with Bash/Zsh which only do word-expansion if there
          # at least one comma listed. E.g. "a_{1,2}" => "a_1 a_2" whereas
          # "a_{1}" => "a_{1}"
          if expansions.length > 1
            return expansions.map { |expansion| str.sub(/\{([^\}]+)\}/, expansion) }
          end
        end
        return [str]
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
