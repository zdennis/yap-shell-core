def very_soon(timeout: 5, &block)
  Timeout.timeout(timeout) do
    loop do
      result = block.call
      break result if result
      sleep 0.1
    end
  end
end
