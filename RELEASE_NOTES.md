# Rails Action Tracker - Release Notes

## Version 0.2.0 - Major Format Enhancement Release

**Release Date:** September 3, 2025

### 🚀 Major New Features

#### Separate Print and Log Format Support
- **Independent Format Control**: Configure different output formats for console display (`print_format`) and file logging (`log_format`)
- **Mix & Match Flexibility**: Use table format for console readability while saving JSON/CSV for analysis
- **Backward Compatible**: Existing `output_format` configuration continues to work seamlessly

#### JSON Accumulation with Intelligent Merging
- **Persistent JSON Logs**: JSON format now accumulates all actions in a single valid JSON file
- **Smart Data Merging**: When the same action is visited multiple times, new tables/services are added to existing data
- **Thread-Safe Operations**: File locking prevents corruption during concurrent writes
- **Separate Behaviors**: 
  - JSON Print: Shows only current action data in clean format
  - JSON Log: Accumulates comprehensive historical data across requests

#### CSV Accumulation with Dynamic Headers
- **Intelligent CSV Accumulation**: CSV format accumulates all actions in a single file with expanding headers
- **Dynamic Schema Evolution**: Headers automatically expand as new tables/services are discovered
- **Smart Access Pattern Merging**: Access patterns merge intelligently (R + W = RW) when same action visited again
- **Separate Behaviors**:
  - CSV Print: Shows only current action data with compact headers
  - CSV Log: Comprehensive accumulated data perfect for spreadsheet analysis

### 🎨 Format Examples

#### JSON Format Behaviors
**Print Output (Console):**
```
UsersController#show: {
  "read": ["users", "posts"],
  "write": ["sessions"],
  "services": ["Redis"]
}
```

**Log Output (Accumulated File):**
```json
{
  "UsersController#show": {
    "read": ["users", "posts", "profiles"],
    "write": ["sessions", "users"],
    "services": ["Redis", "Elasticsearch"]
  },
  "PostsController#create": {
    "read": ["posts", "users"],
    "write": ["posts"],
    "services": ["Sidekiq"]
  }
}
```

#### CSV Format Behaviors
**Print Output (Console):**
```csv
Action,users,posts,sessions,Redis
UsersController#show,R,R,W,Y
```

**Log Output (Accumulated File):**
```csv
Action,Elasticsearch,Redis,Sidekiq,posts,profiles,sessions,users
UsersController#show,Y,Y,-,R,R,W,RW
PostsController#create,-,-,Y,RW,-,-,R
```

### ⚙️ Configuration Enhancements

#### New Configuration Options
```ruby
RailsActionTracker::Tracker.configure(
  print_format: :table,    # Format for console/Rails log: :table, :csv, :json
  log_format: :json,       # Format for log file: :table, :csv, :json
  print_to_rails_log: true,
  write_to_file: true,
  log_file_path: Rails.root.join('log', 'action_tracker.json')
)
```

#### Popular Configuration Patterns

**Development & Debugging:**
```ruby
print_format: :table,     # Easy to read during development
log_format: :json         # Detailed logs for debugging
```

**Performance Analysis:**
```ruby
print_format: :table,     # Console stays readable
log_format: :csv          # Perfect for Excel/Google Sheets
```

**API Documentation Generation:**
```ruby
print_format: :json,      # Immediate JSON feedback
log_format: :json         # Accumulated endpoint data
```

### 🔧 Technical Improvements

#### Enhanced File Handling
- **Automatic Directory Creation**: Log directories are created automatically if they don't exist
- **Malformed File Recovery**: Gracefully handles corrupted JSON/CSV files by starting fresh
- **Atomic File Operations**: All file writes are atomic to prevent partial data corruption
- **Memory Efficient**: Large files are processed efficiently without loading entire contents into memory

#### Logger Optimization
- **Format-Specific Logger Setup**: Only creates custom loggers for formats that need them
- **Reduced File I/O**: JSON and CSV formats write directly to files, avoiding logger overhead
- **No Logger Interference**: Prevents logger headers from corrupting structured data files

### 📊 Use Cases & Benefits

#### Data Analysis
- **Spreadsheet Ready**: CSV accumulation creates files perfect for Excel/Google Sheets analysis
- **Pivot Table Friendly**: Dynamic headers and consistent data structure ideal for pivot tables
- **Historical Trends**: Track how application data access patterns evolve over time

#### Performance Monitoring
- **Access Pattern Analysis**: Identify which actions access the most tables/services
- **Service Usage Tracking**: Monitor service adoption and usage patterns across actions
- **Data Growth Tracking**: Watch as application complexity grows through expanding CSV headers

#### API Documentation
- **Automatic Endpoint Discovery**: JSON accumulation reveals all API endpoints and their data dependencies
- **Real Usage Patterns**: See actual data access patterns instead of theoretical documentation
- **Integration Testing**: Verify that endpoints access expected tables and services

### 🧪 Quality Assurance

#### Comprehensive Testing
- **73 Test Cases**: All features covered with comprehensive test suite
- **403 Assertions**: Thorough validation of all functionality
- **File Operation Testing**: Extensive testing of concurrent file access and merging logic
- **Format Validation**: All output formats validated for correctness and consistency

#### Code Quality
- **RuboCop Compliant**: All code meets Ruby style guidelines
- **Thread Safety**: All operations are thread-safe for production use
- **Error Handling**: Graceful degradation when file operations fail
- **Memory Efficient**: Optimized for minimal memory usage even with large data sets

### 📖 Documentation Updates

#### Comprehensive Examples
- **11 Configuration Examples**: From basic setups to advanced use cases
- **Format Comparison Guide**: Clear explanations of when to use each format
- **Migration Guide**: Smooth upgrade path from v1.x configurations
- **Use Case Documentation**: Real-world scenarios with recommended configurations

#### Updated README
- **Format Behavior Differences**: Clear explanation of print vs log behaviors
- **Configuration Matrix**: All possible format combinations documented
- **Performance Guidelines**: Recommendations for production use
- **Troubleshooting Section**: Common issues and solutions

### 🔄 Backward Compatibility

#### Seamless Upgrades
- **No Breaking Changes**: All v1.x configurations continue to work
- **Automatic Migration**: `output_format` automatically sets both `print_format` and `log_format`
- **Deprecation Warnings**: Clear guidance on migrating to new configuration options
- **Feature Parity**: All v1.x functionality preserved and enhanced

### 🏃‍♂️ Getting Started

#### Quick Setup
```ruby
# Add to your Gemfile
gem 'rails_action_tracker'

# Generate initializer
rails generate rails_action_tracker:install

# Configure for your needs
RailsActionTracker::Tracker.configure(
  print_format: :table,   # Console output
  log_format: :csv,       # File accumulation
  write_to_file: true,
  log_file_path: Rails.root.join('log', 'action_tracker.csv')
)
```

#### Immediate Benefits
- **Zero Learning Curve**: Works immediately with sensible defaults
- **Flexible Configuration**: Easily adjust formats as needs change
- **Production Ready**: Thread-safe and performance optimized
- **Rich Data**: Comprehensive insights into application behavior

### 🔮 Future Enhancements

#### Planned Features
- **Real-time Dashboard**: Web interface for monitoring live data access patterns
- **Alert System**: Notifications when unusual access patterns are detected
- **Export Integrations**: Direct integration with analytics platforms
- **Custom Format Support**: Plugin system for custom output formats

---

**Full Changelog**: [View on GitHub](https://github.com/deepakmahakale/rails_action_tracker/compare/v0.1.0...v0.2.0)

**Upgrade Guide**: See README.md for detailed migration instructions from v0.1.0

**Support**: Report issues on [GitHub Issues](https://github.com/deepakmahakale/rails_action_tracker/issues)

---

## Version 0.1.0 - Initial Release

**Release Date:** January 2, 2025

### 🚀 Core Features

#### ActiveRecord Model Tracking
- **Read Operation Detection**: Automatically tracks SELECT queries across all database tables
- **Write Operation Detection**: Captures INSERT, UPDATE, and DELETE operations
- **Table Classification**: Intelligent parsing of SQL statements to identify affected tables
- **Thread-Safe Tracking**: Each request tracked independently using thread-local storage

#### Service Usage Detection
- **Built-in Service Patterns**: Detects Redis, Sidekiq, Pusher, Honeybadger, ActionMailer, HTTP calls
- **Custom Service Configuration**: Define your own service detection patterns
- **Log Message Analysis**: Scans Rails logs for service usage indicators
- **Automatic Discovery**: No manual instrumentation required

#### Flexible Logging Configuration
- **Rails Logger Integration**: Beautiful colorized table output in development logs
- **Separate File Logging**: Optional plain-text logging to dedicated files
- **Dual Output**: Support for simultaneous Rails log and file output
- **Environment Awareness**: Automatically disabled in test environment

### 🎨 Output Format

#### Table Format Display
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

### ⚙️ Configuration Options

#### Basic Setup
```ruby
RailsActionTracker::Tracker.configure(
  print_to_rails_log: true,  # Colorized output in Rails logs (default: true)
  write_to_file: false,      # Write to separate file (default: false)
  log_file_path: Rails.root.join('log', 'action_tracker.log'),
  
  # Custom service detection
  services: [
    { name: 'Redis', pattern: /redis/i },
    { name: 'CustomAPI', pattern: /custom_api/i }
  ],
  
  # Tables to ignore from tracking
  ignored_tables: ['audit_logs', 'session_data']
)
```

#### Smart Table Filtering
- **System Tables**: Automatically ignores PostgreSQL system tables (`pg_*`)
- **Rails Internals**: Skips `ar_internal_metadata`, `schema_migrations`
- **Custom Filtering**: Configure additional tables to ignore
- **Pattern Matching**: Support for flexible table name patterns

### 🔧 Rails Integration

#### Seamless Setup
- **Rails Generator**: `rails generate rails_action_tracker:install`
- **Automatic Middleware**: Integrated via Rails::Railtie
- **Zero Configuration**: Works out of the box with sensible defaults
- **Hot Reloading**: Configuration changes applied immediately in development

#### Performance Optimized
- **Minimal Overhead**: Efficient SQL parsing and tracking
- **Asset Request Skipping**: No tracking for static assets
- **Test Environment Disabled**: Automatic test environment detection
- **Memory Efficient**: Uses Set data structures for deduplication

### 📊 Use Cases

#### Development & Debugging
- **Quick Insight**: See what data each action touches at a glance
- **N+1 Detection**: Identify repeated database queries
- **Service Dependency**: Understand external service usage patterns
- **Refactoring Aid**: Guide code optimization decisions

#### Performance Analysis
- **Database Access Patterns**: Track which actions are database-heavy
- **Service Usage Tracking**: Monitor external service calls
- **Data Flow Understanding**: Visualize application data dependencies

### 🧪 Quality Assurance

#### Comprehensive Testing
- **45 Test Cases**: Full feature coverage with comprehensive test suite
- **188 Assertions**: Thorough validation of all functionality
- **Multi-Rails Testing**: Appraisal-based testing across Rails 5.0-8.0
- **CI/CD Pipeline**: GitHub Actions for automated testing

#### Code Quality
- **RuboCop Compliant**: Follows Ruby style guidelines
- **Thread Safety**: Safe for production multi-threaded environments
- **Error Handling**: Graceful degradation when tracking fails
- **Documentation**: Comprehensive README and inline documentation

### 🔄 Version Compatibility

#### Ruby Support
- **Ruby 2.7+**: Fully tested and supported
- **Ruby 3.x**: Forward compatible with modern Ruby versions

#### Rails Support
- **Rails 5.0+**: Broad compatibility across Rails versions
- **Rails 6.x**: Fully tested with Rails 6.0 and 6.1
- **Rails 7.x**: Compatible with Rails 7.0
- **Rails 8.x**: Forward compatible

### 🏃‍♂️ Getting Started

#### Installation
```ruby
# Add to Gemfile
gem 'rails_action_tracker'

# Install and configure
bundle install
rails generate rails_action_tracker:install
```

#### Immediate Benefits
- **Zero Learning Curve**: Works immediately after installation
- **Instant Visibility**: See database and service usage patterns right away
- **Development Insights**: Better understanding of application behavior
- **Performance Awareness**: Identify optimization opportunities

### 📖 Documentation

#### Complete Guide
- **Installation Instructions**: Step-by-step setup process  
- **Configuration Examples**: Multiple use case scenarios
- **Customization Guide**: Advanced configuration options
- **Troubleshooting**: Common issues and solutions

---

**Initial Release**: [View on GitHub](https://github.com/deepakmahakale/rails_action_tracker/releases/tag/v0.1.0)

**Documentation**: See README.md for complete setup and usage instructions

**Support**: Report issues on [GitHub Issues](https://github.com/deepakmahakale/rails_action_tracker/issues)