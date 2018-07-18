# Version
require "capapi/version"

# API operations
require "capapi/api_operations/list"
require "capapi/api_operations/request"

# API resource support classes
require "capapi/errors"
require "capapi/util"
require "capapi/capapi_client"
require "capapi/capapi_object"
require "capapi/capapi_response"
require "capapi/list_object"
require "capapi/api_resource"

# Named API resources
require "capapi/case"

module Capapi
  @api_base = "https://capapi.org/api"
  @api_version = 1

  @log_level = nil
  @logger = nil

  @max_network_retries = 0
  @max_network_retry_delay = 2
  @initial_network_retry_delay = 0.5

  @open_timeout = 30
  @read_timeout = 80

  class << self
    attr_accessor :api_key, :api_base, :api_version, :open_timeout, :read_timeout
    attr_reader :max_network_retry_delay, :initial_network_retry_delay
  end

  # map to the same values as the standard library's logger
  LEVEL_DEBUG = Logger::DEBUG
  LEVEL_ERROR = Logger::ERROR
  LEVEL_INFO = Logger::INFO

  # When set prompts the library to log some extra information to $stdout and
  # $stderr about what it's doing. For example, it'll produce information about
  # requests, responses, and errors that are received. Valid log levels are
  # `debug` and `info`, with `debug` being a little more verbose in places.
  #
  # Use of this configuration is only useful when `.logger` is _not_ set. When
  # it is, the decision what levels to print is entirely deferred to the logger.
  def self.log_level
    @log_level
  end

  def self.log_level=(val)
    # Backwards compatibility for values that we briefly allowed
    if val == "debug"
      val = LEVEL_DEBUG
    elsif val == "info"
      val = LEVEL_INFO
    end

    if !val.nil? && ![LEVEL_DEBUG, LEVEL_ERROR, LEVEL_INFO].include?(val)
      raise ArgumentError, "log_level should only be set to `nil`, `debug` or `info`"
    end
    @log_level = val
  end

  # Sets a logger to which logging output will be sent. The logger should
  # support the same interface as the `Logger` class that's part of Ruby's
  # standard library (hint, anything in `Rails.logger` will likely be
  # suitable).
  #
  # If `.logger` is set, the value of `.log_level` is ignored. The decision on
  # what levels to print is entirely deferred to the logger.
  def self.logger
    @logger
  end

  def self.logger=(val)
    @logger = val
  end

  def self.max_network_retries
    @max_network_retries
  end

  def self.max_network_retries=(val)
    @max_network_retries = val.to_i
  end
end

Capapi.log_level = ENV["CAPAPI_LOG"] unless ENV["CAPAPI_LOG"].nil?
