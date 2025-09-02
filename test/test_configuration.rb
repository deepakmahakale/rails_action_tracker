# frozen_string_literal: true

require "test_helper"
require "tempfile"

class TestConfiguration < Minitest::Test
  def setup
    @tracker = RailsActionTracker::Tracker
    @tracker.config = nil
    @tracker.custom_logger = nil
  end

  def teardown
    @tracker.config = nil
    @tracker.custom_logger = nil
  end

  def test_default_configuration_values
    @tracker.configure({})
    
    config = @tracker.config
    assert_equal true, config[:print_to_rails_log]
    assert_equal false, config[:write_to_file]
    assert_nil config[:log_file_path]
    assert_instance_of Array, config[:services]
    assert_instance_of Array, config[:ignored_tables]
  end

  def test_configuration_override
    custom_config = {
      print_to_rails_log: false,
      write_to_file: true,
      log_file_path: "/tmp/custom.log",
      services: [{ name: "Custom", pattern: /custom/i }],
      ignored_tables: ["custom_table"]
    }
    
    @tracker.configure(custom_config)
    
    config = @tracker.config
    assert_equal false, config[:print_to_rails_log]
    assert_equal true, config[:write_to_file]
    assert_equal "/tmp/custom.log", config[:log_file_path]
    assert_equal [{ name: "Custom", pattern: /custom/i }], config[:services]
    assert_equal ["custom_table"], config[:ignored_tables]
  end

  def test_custom_logger_setup_with_valid_path
    temp_file = Tempfile.new('test_log')
    log_path = temp_file.path
    temp_file.close
    
    @tracker.configure(
      write_to_file: true,
      log_file_path: log_path
    )
    
    refute_nil @tracker.custom_logger
    assert_instance_of Logger, @tracker.custom_logger
    
    # Clean up
    File.unlink(log_path) if File.exist?(log_path)
  end

  def test_custom_logger_not_setup_without_path
    @tracker.configure(
      write_to_file: true,
      log_file_path: nil
    )
    
    assert_nil @tracker.custom_logger
  end

  def test_custom_logger_not_setup_when_disabled
    @tracker.configure(
      write_to_file: false,
      log_file_path: "/tmp/test.log"
    )
    
    assert_nil @tracker.custom_logger
  end

  def test_default_ignored_tables_included
    @tracker.configure({})
    
    config = @tracker.config
    ignored_tables = config[:ignored_tables]
    
    # Check for PostgreSQL system tables
    assert_includes ignored_tables, 'pg_attribute'
    assert_includes ignored_tables, 'pg_index'
    assert_includes ignored_tables, 'pg_class'
    assert_includes ignored_tables, 'pg_namespace'
    assert_includes ignored_tables, 'pg_type'
    
    # Check for Rails internal tables
    assert_includes ignored_tables, 'ar_internal_metadata'
    assert_includes ignored_tables, 'schema_migrations'
  end

  def test_ignored_tables_override_replaces_defaults
    @tracker.configure(
      ignored_tables: ['only_this_table']
    )
    
    config = @tracker.config
    assert_equal ['only_this_table'], config[:ignored_tables]
  end

  def test_services_configuration_with_patterns
    custom_services = [
      { name: "Service1", pattern: /service1/i },
      { name: "Service2", pattern: /service2|api2/i }
    ]
    
    @tracker.configure(services: custom_services)
    
    config = @tracker.config
    assert_equal custom_services, config[:services]
  end

  def test_services_configuration_with_strings
    custom_services = ["ServiceName", "AnotherService"]
    
    @tracker.configure(services: custom_services)
    
    config = @tracker.config
    assert_equal custom_services, config[:services]
  end

  def test_config_attribute_accessor
    test_config = { test: "value" }
    @tracker.config = test_config
    
    assert_equal test_config, @tracker.config
  end

  def test_custom_logger_attribute_accessor
    test_logger = Logger.new(StringIO.new)
    @tracker.custom_logger = test_logger
    
    assert_equal test_logger, @tracker.custom_logger
  end
end