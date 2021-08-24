# frozen_string_literal: true

module Logging
  # This is the magical bit that gets mixed into your classes
  def logger
    Logging.logger
  end

  def logging
    logger
  end

  # Global, memoized, lazy initialized instance of a logger
  def self.logger
    @logger ||= Logger.new($stdout)
  end
end
