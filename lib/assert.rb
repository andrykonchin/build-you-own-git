module Assert
  def assert(actual, message = nil)
    if !actual
      raise "Assert failed (#{message})"
    end
  end
end
