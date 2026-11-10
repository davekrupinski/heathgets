require "logger"

module Heathgets
  VERSION = "0.1.0"

  class Error < StandardError; end

  def self.logger
    @logger ||= Logger.new($stdout, progname: "heathgets").tap do |l|
      l.formatter = proc { |sev, time, _prog, msg| "#{time.strftime('%F %T %Z')} #{sev.ljust(5)} #{msg}\n" }
    end
  end

  def self.logger=(logger)
    @logger = logger
  end
end

require_relative "heathgets/fetcher"
require_relative "heathgets/store"
require_relative "heathgets/runner"
