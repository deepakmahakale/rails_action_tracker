# frozen_string_literal: true

require_relative "rails_action_tracker/version"
require_relative "rails_action_tracker/tracker"
require_relative "rails_action_tracker/middleware"

module RailsActionTracker
  class Error < StandardError; end
end

if defined?(Rails) && defined?(Rails::Railtie)
  require_relative "rails_action_tracker/railtie"
end
