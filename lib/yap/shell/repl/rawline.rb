require 'rawline'
require 'yap/shell/repl/highline_ext'

class Yap::Shell::ReplHistorySearch
  def supports_partial_text_matching?
    true
  end

  def supports_matching_text?
    true
  end

  def search_backward(history:, matching_text:)
    upto_index = (history.position || history.length) - 1
    return history.position unless upto_index >= 0

    snapshot = history[0..upto_index].reverse
    no_match = nil

    position = snapshot.each_with_index.reduce(no_match) do |no_match, (text, i)|
      if text =~ /^#{Regexp.escape(matching_text.to_s)}/
        # convert to non-reversed indexing
        position = snapshot.length - (i + 1)
        break position
      else
        no_match
      end
    end
  end

  def search_forward(history:, matching_text:)
    return nil unless history.position

    start_index = history.position + 1
    snapshot = history[start_index..-1].dup
    no_match = nil

    position = snapshot.each_with_index.reduce(no_match) do |no_match, (text, i)|
      if text =~ /^#{Regexp.escape(matching_text.to_s)}/
        position = start_index + i
        break position
      else
        no_match
      end
    end
  end

end
