# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'minitest/autorun'
require 'mocha/minitest'

# Set up a minimal Rails environment for testing
require 'active_support'
require 'active_support/notifications'
require 'action_dispatch'
require 'logger'

# Mock Rails for testing
module Rails
  class << self
    def env
      @env ||= ActiveSupport::StringInquirer.new('test')
    end

    def logger
      @logger ||= Logger.new(StringIO.new)
    end
  end
end

require 'rails_action_tracker'
