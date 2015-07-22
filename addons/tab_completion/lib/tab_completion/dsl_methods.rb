class TabCompletion
  module DslMethods
    def tab_completion(name, pattern, &blk)
      self[:tab_completion].add_completion(name, pattern, &blk)
    end
  end
end


__END__

# generic?
tab_completion '*' do |input_fragment|

end

tab_completion :rake, /^(rake|be rake)\s+(\S+)/ do |input_fragment, match_data|
  `bundle exec rake -T`.split(/\n/).map do |text|
    OpenStruct.new(type: :rake, text: text.gsub(/(^rake\s*|\s*#.*$)/, ''), descriptive_text:text.gsub(/^rake\s*/, ''))
  end
end


* sort completions for printing
* print completion in groups?
* match on command, command with arguments, arguments, env var args
* supply the completion text
* supply the descriptive text
* alias one completion for another
* cache completions? invalidate cached completions
