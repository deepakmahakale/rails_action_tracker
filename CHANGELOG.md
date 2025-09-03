# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2025-09-03

### Added
- **Separate Print and Log Format Support**: Configure different output formats for console display (`print_format`) and file logging (`log_format`)
- **JSON Accumulation**: JSON format now accumulates all actions in a single valid JSON file with intelligent data merging
- **CSV Accumulation**: CSV format accumulates all actions in a single file with dynamic headers that expand as new tables/services are discovered
- **Ruby 3.0 Support**: Full compatibility testing with Ruby 3.0
- **Rails 7.0 and 7.1 Support**: Extended Rails version compatibility through Rails 7.1
- **Enhanced File Operations**: Automatic directory creation, malformed file recovery, atomic file operations
- **Thread-safe File Locking**: Prevents corruption during concurrent writes
- **Smart Access Pattern Merging**: Access patterns merge intelligently (R + W = RW) when same action visited again
- **11 Configuration Examples**: Comprehensive configuration scenarios in initializer template

### Changed
- **Expanded CI Matrix**: Now tests Ruby 2.7 and 3.0 with Rails 6.0, 6.1, 7.0, 7.1 (8 combinations)
- **Improved Code Quality**: Refactored complex methods to meet RuboCop standards
- **Enhanced Documentation**: Updated README with format behavior differences and use cases
- **Test Coverage**: Expanded to 73 test cases with 403 assertions

### Fixed
- **RuboCop Compliance**: Fixed all code complexity and style violations
- **Method Parameter Optimization**: Reduced parameter lists and improved method signatures
- **Logger Interference**: Prevented logger headers from corrupting structured data files

### Deprecated
- `output_format` configuration option (still supported for backward compatibility)

## [0.1.0] - 2025-01-02

### Added
- Initial release of RailsActionTracker gem
- ActiveRecord model read/write operation tracking
- Service usage detection (Redis, Sidekiq, Pusher, HTTP calls, etc.)
- Configurable logging options:
  - Rails logger output with colors
  - Separate log file output (plain text)
  - Both destinations simultaneously
- Controller and action name display in output
- Thread-safe tracking using thread-local storage
- Automatic Rails middleware integration
- Ignored tables configuration (PostgreSQL system tables, Rails internals)
- Custom service detection patterns
- Rails generator for easy setup (`rails generate rails_action_tracker:install`)
- Comprehensive test suite with 45 tests, 188 assertions
- Multi-Rails version support (5.0-8.0) via Appraisal
- Multi-Ruby version support (2.7-3.4)
- GitHub Actions CI/CD pipeline
- Colorized tabular output format

### Features
- **Model Tracking**: Tracks SELECT, INSERT, UPDATE operations on database tables
- **Service Detection**: Automatically detects common services from log messages
- **Flexible Configuration**: Multiple logging destinations and custom patterns
- **Performance Optimized**: Minimal overhead, skips tracking for assets and test environment
- **Rails Integration**: Seamless integration via Railtie and middleware
- **Developer Friendly**: Easy setup with generator and comprehensive documentation

[Unreleased]: https://github.com/deepakmahakale/rails_action_tracker/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/deepakmahakale/rails_action_tracker/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/deepakmahakale/rails_action_tracker/releases/tag/v0.1.0
