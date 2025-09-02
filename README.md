# RailsActionTracker

A Rails gem that provides detailed tracking of ActiveRecord model read/write operations and service usage during controller action execution. This gem helps you understand what your Rails actions are doing under the hood by showing you exactly which models are being accessed and what services are being called.

## Features

- 🔍 Track ActiveRecord model read and write operations
- 🏢 Monitor service usage (Redis, Sidekiq, Pusher, HTTP calls, etc.)
- 📝 Configurable logging options (Rails logger, separate log file, or both)
- 🎨 Colorized tabular output for easy reading
- ⚡ Thread-safe tracking
- 🔧 Customizable service detection patterns
- 🚀 Automatic integration via Rails middleware

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rails_action_tracker'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install rails_action_tracker
```

## Quick Start

1. **Install the gem** (see above)

2. **Generate the configuration file**:
   ```bash
   rails generate rails_action_tracker:install
   ```

3. **Configure the gem** in `config/initializers/rails_action_tracker.rb`:
   ```ruby
   RailsActionTracker::Tracker.configure(
     print_to_rails_log: true,  # Print to Rails logger
     write_to_file: true,       # Also write to separate file
     log_file_path: Rails.root.join('log', 'action_tracker.log')
   )
   ```

4. **Start your Rails server** and make requests. You'll see output like:
   ```
   Models and Services accessed during request:
   +-----------------------+-----------------------+-----------------------+
   | Models Read           | Models Written         | Services Accessed       |
   +-----------------------+-----------------------+-----------------------+
   | users                 | user_sessions         | Redis               |
   | posts                 | audit_logs            | Sidekiq             |
   | comments              |                       | ActionMailer        |
   +-----------------------+-----------------------+-----------------------+
   ```

## Configuration Options

### Basic Configuration

```ruby
RailsActionTracker::Tracker.configure(
  print_to_rails_log: true,  # Print to Rails logger (default: true)
  write_to_file: false,      # Write to separate file (default: false)
  log_file_path: nil,        # Path to separate log file (required if write_to_file: true)
  ignored_tables: []         # Tables to ignore from tracking (optional)
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

## Manual Usage

You can also use the tracker manually in your code:

```ruby
# Start tracking
RailsActionTracker::Tracker.start_tracking

# Your code here...
User.find(1)
Post.create(title: "Hello")

# Print summary and stop tracking
RailsActionTracker::Tracker.print_summary
RailsActionTracker::Tracker.stop_tracking
```

## How It Works

The gem works by:

1. **Installing middleware** that automatically wraps each Rails request
2. **Subscribing to ActiveSupport::Notifications** for SQL queries and other Rails events
3. **Parsing SQL queries** to determine which models are being read from or written to
4. **Detecting service usage** by analyzing log messages and notification payloads
5. **Generating a summary table** showing all the activity for that request

## Thread Safety

The gem is thread-safe and uses thread-local storage to track operations. Each request is tracked independently, so concurrent requests won't interfere with each other.

## Performance Impact

The gem is designed to have minimal performance impact:
- Only active during non-test environments by default
- Uses efficient Set data structures for deduplication
- Subscribes only to necessary notification channels
- Skips tracking for asset requests and common non-action paths

## Development

We welcome contributions! Here's how to get started with development and testing.

### Prerequisites

- Ruby 2.7+ (we test against 2.7, 3.0, 3.1, 3.4)
- Bundler
- Git

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/deepakmahakale/rails_action_tracker.git
   cd rails_action_tracker
   ```

2. **Install dependencies**
   ```bash
   bundle install
   ```

3. **Generate Appraisal gemfiles** (for multi-Rails version testing)
   ```bash
   bundle exec appraisal install
   ```

### Testing

#### Quick Tests (Current Ruby + Latest Rails)
```bash
# Run all tests with current setup
bundle exec rake test

# Run with verbose output
bundle exec rake test TESTOPTS="-v"
```

#### Multi-Rails Version Testing
```bash
# Test against specific Rails version
bundle exec appraisal rails-7.1 rake test
bundle exec appraisal rails-6.1 rake test

# Test all Rails versions (comprehensive)
./script/test-all
```

#### Multi-Ruby Version Testing
We use GitHub Actions for multi-Ruby testing, but you can test locally with rbenv/rvm:

```bash
# Example with rbenv
rbenv shell 3.1.0
bundle install
bundle exec rake test

rbenv shell 2.7.6  
bundle install
bundle exec rake test
```

### Code Quality

#### Run RuboCop (linting)
```bash
# Check for style issues
bundle exec rubocop

# Auto-fix issues where possible
bundle exec rubocop -a
```

#### Run Security Checks
```bash
# Install and run bundle audit
gem install bundler-audit
bundle audit --update

# Install and run Brakeman (if you have a Rails app structure)
gem install brakeman
brakeman --rails4 --no-pager
```

### Testing Your Changes

#### Test Different Scenarios
```bash
# Test specific functionality
bundle exec ruby -Ilib:test test/test_tracker.rb
bundle exec ruby -Ilib:test test/test_middleware.rb

# Test with different configurations
RAILS_ENV=development bundle exec rake test
RAILS_ENV=production bundle exec rake test
```

#### Manual Testing in Rails App
1. Build the gem locally:
   ```bash
   gem build rails_action_tracker.gemspec
   ```

2. In a Rails app, use the local gem:
   ```ruby
   # Gemfile
   gem 'rails_action_tracker', path: '/path/to/local/rails_action_tracker'
   # or
   gem 'rails_action_tracker', '~> 0.1.0', path: '/path/to/local/rails_action_tracker'
   ```

3. Test the functionality:
   ```bash
   cd your_rails_app
   bundle install
   rails generate rails_action_tracker:install
   rails server
   # Make requests and observe the tracking output
   ```

### Supported Versions

The gem is tested against these combinations:

**Ruby Versions:**
- 2.7.x
- 3.0.x  
- 3.1.x
- 3.4.x

**Rails Versions:**
- 5.0.x, 5.1.x, 5.2.x (Ruby 2.7 only)
- 6.0.x (Ruby 2.7, 3.0 only)
- 6.1.x, 7.0.x, 7.1.x (Ruby 2.7, 3.0, 3.1, 3.4)
- 8.0.x (Ruby 3.0, 3.1, 3.4 only)

### Contributing

1. **Fork the repository**
2. **Create your feature branch** (`git checkout -b my-new-feature`)
3. **Write tests** for your changes
4. **Ensure all tests pass**:
   ```bash
   bundle exec rake test
   ./script/test-all  # Test all Rails versions
   bundle exec rubocop  # Check code style
   ```
5. **Commit your changes** (`git commit -am 'Add some feature'`)
6. **Push to the branch** (`git push origin my-new-feature`)
7. **Create a Pull Request**

### Debugging

#### Enable Verbose Logging
```ruby
# In your test or Rails app
RailsActionTracker::Tracker.configure(
  print_to_rails_log: true,
  write_to_file: true,
  log_file_path: 'debug_tracker.log'
)
```

#### Test Individual Components
```bash
# Test just the tracker
bundle exec ruby -Ilib -e "require 'rails_action_tracker'; puts 'Loaded successfully'"

# Test SQL parsing
bundle exec ruby -Ilib:test -e "
require 'test_helper'
tracker = RailsActionTracker::Tracker
tracker.start_tracking
tracker.send(:log_query, 'SELECT * FROM users WHERE id = 1')
puts tracker.stop_tracking
"
```

### Release Process

To release a new version:

1. Update the version number in `lib/rails_action_tracker/version.rb`
2. Update `CHANGELOG.md` with new changes
3. Run the full test suite: `./script/test-all`
4. Commit changes: `git commit -am 'Release v0.x.x'`
5. Create git tag: `git tag v0.x.x`
6. Push changes: `git push origin master --tags`
7. Build and push gem: `bundle exec rake release`

### Project Structure

```
├── lib/
│   ├── rails_action_tracker/
│   │   ├── tracker.rb          # Core tracking logic
│   │   ├── middleware.rb       # Rails middleware integration
│   │   ├── railtie.rb         # Rails engine integration
│   │   └── version.rb         # Version definition
│   └── rails_action_tracker.rb # Main entry point
├── test/                      # Test suite
├── gemfiles/                  # Appraisal-generated gemfiles
├── script/test-all           # Multi-version testing script
└── .github/workflows/ci.yml  # GitHub Actions CI
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/deepakmahakale/rails_action_tracker.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
