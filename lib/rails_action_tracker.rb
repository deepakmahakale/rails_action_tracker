# frozen_string_literal: true

require_relative 'rails_action_tracker/version'
require_relative 'rails_action_tracker/tracker'
require_relative 'rails_action_tracker/middleware'

module RailsActionTracker
  class Error < StandardError; end
end

require_relative 'rails_action_tracker/railtie' if defined?(Rails) && defined?(Rails::Railtie)
