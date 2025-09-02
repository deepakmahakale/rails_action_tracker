# Development Guide

We welcome contributions! Here's how to get started with development and testing.

## Prerequisites

- Ruby 2.7+ (we test against 2.7, 3.0, 3.1, 3.4)
- Bundler
- Git

## Setup

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

## Testing

### Quick Tests (Current Ruby + Latest Rails)
```bash
# Run all tests with current setup
bundle exec rake test

# Run with verbose output
bundle exec rake test TESTOPTS="-v"
```

### Multi-Rails Version Testing
```bash
# Test against specific Rails version
bundle exec appraisal rails-7.1 rake test
bundle exec appraisal rails-6.1 rake test

# Test all Rails versions (comprehensive)
./script/test-all
```

### Multi-Ruby Version Testing
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

## Code Quality

### Run RuboCop (linting)
```bash
# Check for style issues
bundle exec rubocop

# Auto-fix issues where possible
bundle exec rubocop -a
```

### Run Security Checks
```bash
# Install and run bundle audit
gem install bundler-audit
bundle audit --update

# Install and run Brakeman (if you have a Rails app structure)
gem install brakeman
brakeman --rails4 --no-pager
```

## Testing Your Changes

### Test Different Scenarios
```bash
# Test specific functionality
bundle exec ruby -Ilib:test test/test_tracker.rb
bundle exec ruby -Ilib:test test/test_middleware.rb

# Test with different configurations
RAILS_ENV=development bundle exec rake test
RAILS_ENV=production bundle exec rake test
```

### Manual Testing in Rails App
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

## Supported Versions

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

## Debugging

### Enable Verbose Logging
```ruby
# In your test or Rails app
RailsActionTracker::Tracker.configure(
  print_to_rails_log: true,
  write_to_file: true,
  log_file_path: 'debug_tracker.log'
)
```

### Test Individual Components
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

## Release Process

To release a new version:

1. Update the version number in `lib/rails_action_tracker/version.rb`
2. Update `CHANGELOG.md` with new changes
3. Run the full test suite: `./script/test-all`
4. Commit changes: `git commit -am 'Release v0.x.x'`
5. Create git tag: `git tag v0.x.x`
6. Push changes: `git push origin master --tags`
7. Build and push gem: `bundle exec rake release`

## Project Structure

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
