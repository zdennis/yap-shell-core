RSpec::Matchers.define :have_not_printed do |expected|
  output_seen_so_far = ""

  match do |block|
    regex = expected
    regex = /#{Regexp.escape(regex)}/m unless regex.is_a?(Regexp)
    begin
      very_soon do
        current_output = block.call
        output_seen_so_far << current_output
        current_output.length > 0
      end
    rescue Timeout::Error
      return true # we didn't see it, make the assumption we're good
    end
    !regex.match(output_seen_so_far)
  end

  failure_message do |actual|
    if expected.is_a?(Regexp)
      "expected that #{expected.inspect} would not match #{output_seen_so_far.inspect}"
    else
      "expected that #{expected.inspect} would not appear in #{output_seen_so_far.inspect}"
    end
  end

  def supports_block_expectations?
    true
  end
end
