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
  log_file_path: nil         # Path to separate log file (required if write_to_file: true)
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

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/deepakmahakale/rails_action_tracker.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
