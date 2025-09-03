# frozen_string_literal: true

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

  # Format for console/Rails log output: :table (default), :csv, or :json
  print_format: :table,

  # Format for log file output: :table, :csv, or :json (defaults to print_format if not specified)
  log_format: :table,

  # Deprecated: Use print_format and log_format instead
  # output_format: :table,

  # Custom service detection patterns (optional)
  # You can define custom services to track beyond the defaults
  services: [
    { name: 'Redis', pattern: /redis/i },
    { name: 'Sidekiq', pattern: /sidekiq/i },
    { name: 'Pusher', pattern: /pusher/i },
    { name: 'Honeybadger', pattern: /honeybadger/i },
    { name: 'ActionMailer', pattern: /mail|email/i },
    { name: 'HTTP', pattern: /http|api/i },
    { name: 'Elasticsearch', pattern: /elasticsearch/i }
    # Add your custom services here
    # { name: "CustomService", pattern: /custom_pattern/i },
  ],

  # Tables to ignore during tracking (optional)
  # These tables will not appear in the tracking output
  ignored_tables: [
    'pg_attribute', # PostgreSQL system table
    'pg_index',           # PostgreSQL system table
    'pg_class',           # PostgreSQL system table
    'pg_namespace',       # PostgreSQL system table
    'pg_type',            # PostgreSQL system table
    'ar_internal_metadata', # Rails internal table
    'schema_migrations' # Rails migrations table
    # Add your custom ignored tables here
    # 'audit_logs',
    # 'session_data'
  ],

  # Controllers to ignore completely (optional)
  # All actions from these controllers will be ignored
  ignored_controllers: [
    # 'Rails::PwaController',  # Ignore PWA controller completely
    # 'HealthCheckController', # Ignore health check controller
    # 'Assets::ServingController'
  ],

  # Specific controller#action combinations to ignore (optional)
  # Flexible patterns for fine-grained control
  ignored_actions: {
    # Ignore specific actions for specific controllers
    # 'ApplicationController' => ['ping', 'status', 'health'],
    # 'ApiController' => ['heartbeat', 'version'],
    # 'AdminController' => ['dashboard_stats'],

    # Ignore entire controllers using empty arrays or nil
    # 'Rails::PwaController' => [],  # Empty array = ignore entire controller
    # 'HealthController' => nil,     # nil = ignore entire controller

    # Global action ignoring (ignore actions across ALL controllers)
    # '' => ['ping', 'health', 'status']  # Empty string key = applies to all controllers
  }
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

# Configuration 4: With controller/action filtering
# RailsActionTracker::Tracker.configure(
#   print_to_rails_log: true,
#   ignored_controllers: ['Rails::PwaController', 'HealthCheckController'],
#   ignored_actions: {
#     '' => ['ping', 'health'],                    # Global actions to ignore
#     'ApplicationController' => ['status'],        # Controller-specific actions
#     'MonitoringController' => [],                 # Ignore entire controller
#     'ApiController' => ['heartbeat', 'version']   # Multiple specific actions
#   }
# )

# Configuration 5: CSV format output
# RailsActionTracker::Tracker.configure(
#   output_format: :csv,
#   print_to_rails_log: true
# )
# Example CSV output:
# Action,table1,table2,table3,Redis,Sidekiq
# JobsController#show,R,R,R,Y,-
# JobsController#update,R,RW,W,Y,Y

# Configuration 6: Different print and log formats
# RailsActionTracker::Tracker.configure(
#   print_format: :json,        # Console shows JSON for current action only
#   log_format: :csv,           # Log file saves in CSV format
#   print_to_rails_log: true,
#   write_to_file: true,
#   log_file_path: Rails.root.join('log', 'action_tracker.csv')
# )
# Print output (Rails log):
# JobsController#show: {
#   "read": ["table1", "table2", "table3"],
#   "write": [],
#   "services": ["Redis"]
# }
# Log file output (CSV format):
# Action,table1,table2,table3,Redis
# JobsController#show,R,R,R,Y

# Configuration 7: JSON accumulation in log file, table in console
# RailsActionTracker::Tracker.configure(
#   print_format: :table,       # Console shows table format
#   log_format: :json,          # Log file accumulates JSON data
#   print_to_rails_log: true,
#   write_to_file: true,
#   log_file_path: Rails.root.join('log', 'action_tracker.json')
# )
# Print output: Standard table format in Rails log
# Log file output: Accumulated JSON structure like:
# {
#   "JobsController#show": {
#     "read": ["table1", "table2", "table3"],
#     "write": [],
#     "services": ["Redis"]
#   },
#   "JobsController#update": {
#     "read": ["table1", "table2"],
#     "write": ["table1"],
#     "services": ["Redis", "Sidekiq"]
#   }
# }

# Configuration 8: JSON print and JSON log (different behaviors)
# RailsActionTracker::Tracker.configure(
#   print_format: :json,        # Console shows current action JSON
#   log_format: :json,          # Log file accumulates all actions
#   print_to_rails_log: true,
#   write_to_file: true,
#   log_file_path: Rails.root.join('log', 'action_tracker.json')
# )
# Print: Shows only current action's JSON data
# Log: Accumulates all actions in a single JSON structure

# Configuration 9: Backward compatibility (deprecated but still supported)
# RailsActionTracker::Tracker.configure(
#   output_format: :json        # Will set both print_format and log_format to :json
# )
# Note: output_format is deprecated, use print_format and log_format for better control
