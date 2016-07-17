RSpec::Matchers.define :have_exit_code do |expected|
  shell = nil

  match do |block|
    shell = block.call
    Timeout.timeout(60) do
      loop do
        break if shell.exited?
        sleep 0.01
      end
      expect(shell.exit_code).to eq expected
    end
  end

  failure_message do |actual|
    "expected that the last command would have exit code of #{expected}, but it had #{shell.exit_code.inspect}"
  end

  def supports_block_expectations?
    true
  end
end
