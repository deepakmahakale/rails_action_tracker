# frozen_string_literal: true

module RailsActionTracker
  class Railtie < Rails::Railtie
    config.rails_action_tracker = ActiveSupport::OrderedOptions.new

    initializer 'rails_action_tracker.configure', before: :load_config_initializers do |_app|
      RailsActionTracker::Tracker.configure({})
    end

    initializer 'rails_action_tracker.reconfigure', after: :load_config_initializers do |app|
      options = {}
      app.config.rails_action_tracker.each_pair do |key, value|
        options[key] = value
      end
      RailsActionTracker::Tracker.configure(options)
    end

    initializer 'rails_action_tracker.middleware', after: :load_config_initializers do |app|
      app.middleware.use RailsActionTracker::Middleware
    end
  end
end
