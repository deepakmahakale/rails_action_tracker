# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/deepakmahakale/rails_action_tracker/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/deepakmahakale/rails_action_tracker/releases/tag/v0.1.0