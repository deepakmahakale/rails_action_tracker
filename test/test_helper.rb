# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'minitest/autorun'
require 'mocha/minitest'

# Set up a minimal Rails environment for testing
# Require logger first to avoid Rails 6.1 LoggerThreadSafeLevel issues
require 'logger'

# Ensure Logger constant is available globally before ActiveSupport loads
Object.const_set(:Logger, Logger) unless defined?(::Logger)

require 'active_support'
require 'active_support/notifications'
require 'action_dispatch'

# Mock Rails for testing
module Rails
  class << self
    attr_writer :env, :logger

    def env
      @env ||= ActiveSupport::StringInquirer.new('test')
    end

    def logger
      @logger ||= Logger.new(StringIO.new)
    end
  end
end

require 'rails_action_tracker'
