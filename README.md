# RailsActionTracker

A Rails gem that tracks ActiveRecord model operations and service usage during controller action execution. See what your Rails actions are doing under the hood.

## Installation

Add to your Gemfile:

```ruby
gem 'rails_action_tracker'
```

Install and generate configuration:

```bash
bundle install
rails generate rails_action_tracker:install
```

Start your Rails server and see the output:

```
UsersController#show - Models and Services accessed during request:
+-------------------+-------------------+-------------------+
| Models Read       | Models Written    | Services Accessed |
+-------------------+-------------------+-------------------+
| users             | user_sessions     | Redis             |
| posts             | audit_logs        | Sidekiq           |
| comments          |                   | ActionMailer      |
+-------------------+-------------------+-------------------+
```

## Configuration

The gem works with sensible defaults out of the box. The generated initializer provides full configuration options:

```ruby
# config/initializers/rails_action_tracker.rb
RailsActionTracker::Tracker.configure(
  print_to_rails_log: true,  # Print to Rails logger (default: true)
  write_to_file: false,      # Write to separate file (default: false)
  log_file_path: Rails.root.join('log', 'action_tracker.log'),

  # Output format controls (new in v2.0+)
  print_format: :table,      # Format for console/Rails log: :table, :csv, :json
  log_format: :table,        # Format for log file: :table, :csv, :json

  # Custom services to track (optional)
  services: [
    { name: 'Redis', pattern: /redis/i },
    { name: 'Sidekiq', pattern: /sidekiq/i },
    { name: 'CustomAPI', pattern: /custom_api/i }
  ],

  # Tables to ignore (optional)
  ignored_tables: ['audit_logs', 'session_data']
)
```

### Output Formats

**🎨 New in v2.0+**: The gem now supports different output formats and allows you to configure separate formats for console output and file logging.

#### Available Formats

1. **`:table`** - Clean tabular format (default)
2. **`:csv`** - CSV format with dynamic headers
3. **`:json`** - JSON format with different behaviors for print vs log

#### Format Configuration

```ruby
RailsActionTracker::Tracker.configure(
  print_format: :table,      # Format for console/Rails log output
  log_format: :json,         # Format for log file output (can be different!)
  
  print_to_rails_log: true,  # Enable console output
  write_to_file: true,       # Enable file logging
  log_file_path: Rails.root.join('log', 'action_tracker.json')
)
```

#### Format Examples

**Table Format (:table)**
```
UsersController#show - Models and Services accessed during request:
+-------------------+-------------------+-------------------+
| Models Read       | Models Written    | Services Accessed |
+-------------------+-------------------+-------------------+
| users             | user_sessions     | Redis             |
| posts             | audit_logs        | Sidekiq           |
+-------------------+-------------------+-------------------+
```

**CSV Print Format (:csv for console)**
```
Action,users,posts,user_sessions,Redis
UsersController#show,R,R,W,Y
```

**CSV Log Format (:csv for file - accumulative)**
```csv
Action,Elasticsearch,Redis,Sidekiq,posts,profiles,sessions,users
UsersController#show,Y,Y,-,R,R,W,RW
PostsController#create,-,-,Y,RW,-,-,R
```

**JSON Print Format (:json for console)**
```
UsersController#show: {
  "read": ["users", "posts"],
  "write": ["user_sessions", "audit_logs"],
  "services": ["Redis", "Sidekiq"]
}
```

**JSON Log Format (:json for file - accumulative)**
```json
{
  "UsersController#show": {
    "read": ["users", "posts"],
    "write": ["user_sessions"],
    "services": ["Redis"]
  },
  "UsersController#update": {
    "read": ["users", "posts"],
    "write": ["users", "audit_logs"],
    "services": ["Redis", "Sidekiq"]
  }
}
```

#### Format Behavior Differences

Both JSON and CSV formats behave differently for print vs log:

**JSON Format:**
- **JSON Print** (console): Shows only current action data in clean format
- **JSON Log** (file): Accumulates all actions in a persistent structure, merging new data when the same action is visited again

**CSV Format:**
- **CSV Print** (console): Shows only current action data with compact headers
- **CSV Log** (file): Accumulates all actions in a single CSV file with dynamic headers that expand as new tables/services are encountered. When the same action is visited again, access patterns are merged intelligently (e.g., R + W = RW)

**Table Format:**
- **Table Print** (console): Shows current action data in formatted table
- **Table Log** (file): Each action logged separately in table format (no accumulation)

### Configuration Options

**Basic Configuration**

```ruby
RailsActionTracker::Tracker.configure(
  print_to_rails_log: true,  # Print to Rails logger (default: true)
  write_to_file: false,      # Write to separate file (default: false)
  log_file_path: nil,        # Path to separate log file (required if write_to_file: true)
  
  print_format: :table,      # Format for console output: :table, :csv, :json
  log_format: :table,        # Format for file output (defaults to print_format)
  
  ignored_tables: [],        # Tables to ignore from tracking (optional)
  ignored_controllers: [],   # Controllers to completely ignore (optional)
  ignored_actions: {}        # Specific controller#action combinations to ignore (optional)
)
```

### Configuration Examples

**Option 1: Only log to Rails logger (default)**
```ruby
RailsActionTracker::Tracker.configure(
  print_to_rails_log: true,
  write_to_file: false
)
```

**Option 2: Only log to separate file**
```ruby
RailsActionTracker::Tracker.configure(
  print_to_rails_log: false,
  write_to_file: true,
  log_file_path: Rails.root.join('log', 'action_tracker.log')
)
```

**Option 3: Log to both Rails logger and separate file**
```ruby
RailsActionTracker::Tracker.configure(
  print_to_rails_log: true,
  write_to_file: true,
  log_file_path: Rails.root.join('log', 'action_tracker.log')
)
```

### Format Configuration Examples

**Option 4: Different print and log formats**
```ruby
RailsActionTracker::Tracker.configure(
  print_format: :json,        # Console shows clean JSON for current action
  log_format: :csv,           # File saves in CSV format for analysis
  print_to_rails_log: true,
  write_to_file: true,
  log_file_path: Rails.root.join('log', 'action_tracker.csv')
)
```

**Option 5: JSON accumulation for analysis**
```ruby
RailsActionTracker::Tracker.configure(
  print_format: :table,       # Console shows familiar table format
  log_format: :json,          # File accumulates JSON data across requests
  print_to_rails_log: true,
  write_to_file: true,
  log_file_path: Rails.root.join('log', 'action_tracker.json')
)
```

**Option 6: CSV accumulation for spreadsheet analysis**
```ruby
RailsActionTracker::Tracker.configure(
  print_format: :table,       # Console shows table
  log_format: :csv,           # File accumulates CSV with dynamic columns
  print_to_rails_log: true,
  write_to_file: true,
  log_file_path: Rails.root.join('log', 'action_tracker.csv')
)
```
# Results in accumulated CSV like:
# Action,Redis,Sidekiq,posts,profiles,users
# UsersController#show,Y,-,R,R,RW
# PostsController#create,-,Y,RW,-,R

**Option 7: CSV print and CSV log (different behaviors)**
```ruby
RailsActionTracker::Tracker.configure(
  print_format: :csv,         # Console shows current action CSV
  log_format: :csv,           # File accumulates all actions with smart merging
  print_to_rails_log: true,
  write_to_file: true,
  log_file_path: Rails.root.join('log', 'action_tracker.csv')
)
```
# Print: Shows only current action's CSV data with minimal headers
# Log: Accumulates all actions with expanding headers and intelligent merging

**Option 8: JSON everywhere with different behaviors**
```ruby
RailsActionTracker::Tracker.configure(
  print_format: :json,        # Console: current action JSON only
  log_format: :json,          # File: accumulative JSON structure
  print_to_rails_log: true,
  write_to_file: true,
  log_file_path: Rails.root.join('log', 'action_tracker.json')
)
```

### Migration from v1.x

If you're upgrading from v1.x and using `output_format`, the gem maintains backward compatibility:

```ruby
# Old configuration (still works)
RailsActionTracker::Tracker.configure(
  output_format: :json  # Sets both print_format and log_format to :json
)

# New configuration (recommended)
RailsActionTracker::Tracker.configure(
  print_format: :table,  # Different formats for different outputs
  log_format: :json
)
```

### Custom Service Detection

You can customize which services are detected by providing custom patterns:

```ruby
RailsActionTracker::Tracker.configure(
  print_to_rails_log: true,
  services: [
    { name: "Redis", pattern: /redis/i },
    { name: "CustomAPI", pattern: /custom_api|my_service/i },
    { name: "PaymentGateway", pattern: /stripe|paypal/i }
  ]
)
```

### Ignoring Tables

You can specify tables to ignore from tracking (useful for system tables, audit logs, etc.):

```ruby
RailsActionTracker::Tracker.configure(
  print_to_rails_log: true,
  ignored_tables: [
    'pg_attribute',        # PostgreSQL system tables
    'pg_index',
    'pg_class',
    'ar_internal_metadata', # Rails internal tables
    'schema_migrations',
    'audit_logs',          # Your custom tables to ignore
    'session_data'
  ]
)
```

**Default ignored tables:**
- `pg_attribute`, `pg_index`, `pg_class`, `pg_namespace`, `pg_type` (PostgreSQL system tables)
- `ar_internal_metadata`, `schema_migrations` (Rails internal tables)

### Ignoring Controllers and Actions

You have flexible options for ignoring controllers and actions to reduce noise:

#### Simple Controller Ignoring
```ruby
RailsActionTracker::Tracker.configure(
  # Ignore entire controllers (all actions)
  ignored_controllers: [
    'Rails::PwaController',  # Ignore PWA controller completely
    'HealthCheckController', # Ignore health check controller
    'Assets::ServingController'
  ]
)
```

#### Basic Action Ignoring
```ruby
RailsActionTracker::Tracker.configure(
  # Ignore specific controller#action combinations
  ignored_actions: {
    'ApplicationController' => ['ping', 'status'],  # Ignore specific actions
    'ApiController' => ['heartbeat'],               # Multiple controllers
    'AdminController' => ['dashboard_stats']        # can have ignored actions
  }
)
```

#### Advanced Flexible Action Ignoring

The `ignored_actions` configuration supports flexible patterns:

**1. Ignore entire controller by providing empty actions array:**
```ruby
RailsActionTracker::Tracker.configure(
  ignored_actions: {
    'Rails::PwaController' => [],  # Empty array = ignore entire controller
    'HealthController' => nil      # nil = ignore entire controller
  }
)
```

**2. Ignore specific actions for multiple controllers:**
```ruby
RailsActionTracker::Tracker.configure(
  ignored_actions: {
    'ApplicationController' => ['ping', 'status', 'health'],
    'ApiController' => ['heartbeat', 'version'],
    'AdminController' => ['dashboard_stats', 'system_info']
  }
)
```

**3. Global action ignoring (ignore actions across ALL controllers):**
```ruby
RailsActionTracker::Tracker.configure(
  ignored_actions: {
    '' => ['ping', 'status', 'health']  # Empty string key = applies to all controllers
  }
)
```

This will ignore the `ping`, `status`, and `health` actions regardless of which controller they're called from.

**4. Combined patterns:**
```ruby
RailsActionTracker::Tracker.configure(
  ignored_controllers: [
    'Rails::PwaController'  # Ignore this controller completely
  ],
  ignored_actions: {
    '' => ['ping', 'health'],                    # Global actions to ignore
    'ApplicationController' => ['status'],        # Controller-specific actions
    'MonitoringController' => [],                 # Ignore entire controller
    'ApiController' => ['heartbeat', 'version']   # Multiple specific actions
  }
)
```

#### Common Use Cases

**Ignore noisy Rails controllers:**
```ruby
ignored_controllers: ['Rails::PwaController', 'Rails::ConductorController']
```

**Ignore health/monitoring endpoints:**
```ruby
ignored_actions: {
  '' => ['ping', 'health', 'status', 'heartbeat']  # Global ignore
}
```

**Ignore admin dashboard noise:**
```ruby
ignored_actions: {
  'AdminController' => ['dashboard_stats', 'system_metrics'],
  'MonitoringController' => []  # Ignore entire monitoring controller
}
```

**Development/debugging setup:**
```ruby
ignored_actions: {
  '' => ['ping', 'health'],  # Always ignore these
  'DevelopmentController' => [], # Ignore entire dev controller
  'TestController' => ['debug', 'trace']
}
```

## Manual Usage

You can also use the tracker manually in your code:

```ruby
RailsActionTracker::Tracker.start_tracking

# Your code here...
User.find(1)
Post.create(title: "Hello")

RailsActionTracker::Tracker.print_summary
RailsActionTracker::Tracker.stop_tracking
```

## Format Use Cases

### Development & Debugging
```ruby
# Clean console output, detailed JSON logs for analysis
RailsActionTracker::Tracker.configure(
  print_format: :table,       # Easy to read during development
  log_format: :json,          # Detailed logs for debugging
  print_to_rails_log: true,
  write_to_file: true,
  log_file_path: Rails.root.join('log', 'action_tracker.json')
)
```

### Performance Analysis
```ruby
# CSV accumulation for importing into spreadsheet tools
RailsActionTracker::Tracker.configure(
  print_format: :table,       # Console stays readable
  log_format: :csv,           # Perfect for Excel/Google Sheets with accumulated data
  print_to_rails_log: true,
  write_to_file: true,
  log_file_path: Rails.root.join('log', 'performance_analysis.csv')
)
```
# Results in comprehensive CSV with all actions and merged access patterns
# Headers expand automatically as new tables/services are discovered
# Perfect for pivot tables and data analysis

### API Documentation Generation
```ruby
# JSON logs for automated API documentation
RailsActionTracker::Tracker.configure(
  print_format: :json,        # Immediate JSON feedback
  log_format: :json,          # Accumulated endpoint data
  print_to_rails_log: true,
  write_to_file: true,
  log_file_path: Rails.root.join('log', 'api_endpoints.json')
)
```

### Monitoring & Alerting
```ruby
# CSV for log aggregation systems
RailsActionTracker::Tracker.configure(
  print_format: :table,       # Human-readable console
  log_format: :csv,           # Machine-readable logs
  print_to_rails_log: false,  # Reduce console noise
  write_to_file: true,
  log_file_path: Rails.root.join('log', 'monitoring.csv')
)
```

## How It Works

The gem integrates seamlessly with Rails:

1. **Automatic middleware** wraps each request
2. **ActiveSupport::Notifications** captures SQL queries and Rails events
3. **Smart parsing** identifies model read/write operations
4. **Service detection** tracks common Rails services (Redis, Sidekiq, etc.)
5. **Thread-safe** - each request tracked independently

## Features

- 🔍 **Model tracking** - See which ActiveRecord models are read/written
- 🏢 **Service detection** - Monitor Redis, Sidekiq, HTTP calls, and more
- 📝 **Flexible logging** - Rails logger, separate files, or both
- 🎨 **Multiple output formats** - Table, CSV, and JSON formats with separate print/log controls
- 📊 **JSON accumulation** - Persistent JSON logs that merge data across requests
- 🔄 **Format flexibility** - Different formats for console vs file output
- ⚡ **Zero configuration** - Works immediately after installation
- 🧵 **Thread-safe** - Handles concurrent requests properly
- 🚀 **Production ready** - Minimal performance impact
- 🔧 **Backward compatible** - Seamless upgrade from v1.x configurations

## Thread Safety

The gem is thread-safe and uses thread-local storage to track operations. Each request is tracked independently, so concurrent requests won't interfere with each other.

## Performance Impact

The gem is designed to have minimal performance impact:
- Only active during non-test environments by default
- Uses efficient Set data structures for deduplication
- Subscribes only to necessary notification channels
- Skips tracking for asset requests and common non-action paths

## Supported Rails Versions

This gem is tested and compatible with:

**Ruby Versions:** 2.7.x, 3.0.x, 3.1.x, 3.4.x

**Rails Versions:** 5.0+ through 8.0+ (see our CI for the full compatibility matrix)

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/deepakmahakale/rails_action_tracker.

For development setup and contribution guidelines, see:
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contribution guidelines and process
- [DEVELOPMENT.md](DEVELOPMENT.md) - Development setup and testing instructions

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
