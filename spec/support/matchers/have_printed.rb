def very_soon(timeout: 5, &block)
  Timeout.timeout(timeout) do
    loop do
      result = block.call
      break result if result
      sleep 0.1
    end
  end
end


RSpec::Matchers.define :have_not_printed do |expected|
  output_seen_so_far = ""

  match do |block|
    begin
      regex = expected
      regex = /#{Regexp.escape(regex)}/m unless regex.is_a?(Regexp)
      very_soon do
        current_output = block.call
        output_seen_so_far << current_output
        !regex.match(current_output)
      end
      true
    rescue Timeout::Error
      false
    end
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

RSpec::Matchers.define :have_printed do |expected|
  output_seen_so_far = ""

  match do |block|
    begin
      regex = expected
      regex = /#{Regexp.escape(regex)}/m unless regex.is_a?(Regexp)
      very_soon do
        current_output = block.call
        output_seen_so_far << current_output
        regex.match(current_output)
      end
      true
    rescue Timeout::Error
      false
    end
  end

  failure_message do |actual|
    if expected.is_a?(Regexp)
      "expected that #{expected.inspect} would match #{output_seen_so_far.inspect}"
    else
      "expected that #{expected.inspect} would appear in #{output_seen_so_far.inspect}"
    end
  end

  def supports_block_expectations?
    true
  end
end
