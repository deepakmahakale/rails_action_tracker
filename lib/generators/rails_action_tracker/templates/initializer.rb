# RailsActionTracker Configuration
# 
# This gem tracks ActiveRecord model operations and service usage during Rails action calls.

RailsActionTracker::Tracker.configure(
  # Whether to print summary to Rails log (default: true)
  print_to_rails_log: true,

  # Whether to write summary to separate log file (default: false)
  write_to_file: false,

  # Path to separate log file (required if write_to_file is true)
  log_file_path: Rails.root.join('log', 'action_tracker.log'),

  # Custom service detection patterns (optional)
  # You can define custom services to track beyond the defaults
  services: [
    { name: "Redis", pattern: /redis/i },
    { name: "Sidekiq", pattern: /sidekiq/i },
    { name: "Pusher", pattern: /pusher/i },
    { name: "Honeybadger", pattern: /honeybadger/i },
    { name: "ActionMailer", pattern: /mail|email/i },
    { name: "HTTP", pattern: /http|api/i },
    { name: "Elasticsearch", pattern: /elasticsearch/i },
    # Add your custom services here
    # { name: "CustomService", pattern: /custom_pattern/i },
  ]
)

# Example configurations:

# Configuration 1: Only log to Rails logger (default)
# RailsActionTracker::Tracker.configure(
#   print_to_rails_log: true,
#   write_to_file: false
# )

# Configuration 2: Only log to separate file
# RailsActionTracker::Tracker.configure(
#   print_to_rails_log: false,
#   write_to_file: true,
#   log_file_path: Rails.root.join('log', 'action_tracker.log')
# )

# Configuration 3: Log to both Rails logger and separate file
# RailsActionTracker::Tracker.configure(
#   print_to_rails_log: true,
#   write_to_file: true,
#   log_file_path: Rails.root.join('log', 'action_tracker.log')
# )