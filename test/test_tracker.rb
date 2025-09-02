# frozen_string_literal: true

require "test_helper"

class TestTracker < Minitest::Test
  def setup
    @tracker = RailsActionTracker::Tracker
    @tracker.config = nil
    @tracker.custom_logger = nil
    
    # Clear any existing subscriptions
    @tracker.send(:unsubscribe_from_sql_notifications)
    @tracker.send(:unsubscribe_from_logger)
  end

  def teardown
    @tracker.stop_tracking
    @tracker.config = nil
    @tracker.custom_logger = nil
  end

  def test_default_configuration
    @tracker.configure({})
    
    config = @tracker.config
    assert_equal true, config[:print_to_rails_log]
    assert_equal false, config[:write_to_file]
    assert_nil config[:log_file_path]
    assert_includes config[:ignored_tables], 'pg_attribute'
    assert_includes config[:ignored_tables], 'schema_migrations'
  end

  def test_custom_configuration
    @tracker.configure(
      print_to_rails_log: false,
      write_to_file: true,
      log_file_path: '/tmp/test.log',
      ignored_tables: ['custom_table']
    )
    
    config = @tracker.config
    assert_equal false, config[:print_to_rails_log]
    assert_equal true, config[:write_to_file]
    assert_equal '/tmp/test.log', config[:log_file_path]
    assert_equal ['custom_table'], config[:ignored_tables]
  end

  def test_start_and_stop_tracking
    @tracker.start_tracking
    
    thread_data = Thread.current[@tracker::THREAD_KEY]
    refute_nil thread_data
    assert_instance_of Set, thread_data[:read]
    assert_instance_of Set, thread_data[:write]
    assert_instance_of Array, thread_data[:captured_logs]
    
    logs = @tracker.stop_tracking
    assert_instance_of Hash, logs
    assert_nil Thread.current[@tracker::THREAD_KEY]
  end

  def test_log_query_select
    @tracker.start_tracking
    
    sql = "SELECT * FROM users WHERE id = 1"
    @tracker.send(:log_query, sql)
    
    logs = Thread.current[@tracker::THREAD_KEY]
    assert_includes logs[:read], 'users'
    assert_empty logs[:write]
  end

  def test_log_query_insert
    @tracker.start_tracking
    
    sql = "INSERT INTO posts (title) VALUES ('test')"
    @tracker.send(:log_query, sql)
    
    logs = Thread.current[@tracker::THREAD_KEY]
    assert_includes logs[:write], 'posts'
    assert_empty logs[:read]
  end

  def test_log_query_update
    @tracker.start_tracking
    
    sql = "UPDATE comments SET content = 'updated' WHERE id = 1"
    @tracker.send(:log_query, sql)
    
    logs = Thread.current[@tracker::THREAD_KEY]
    assert_includes logs[:write], 'comments'
    assert_empty logs[:read]
  end

  def test_ignored_tables_filtering
    @tracker.configure(ignored_tables: ['pg_attribute', 'custom_ignore'])
    @tracker.start_tracking
    
    # These should be ignored
    @tracker.send(:log_query, "SELECT * FROM pg_attribute")
    @tracker.send(:log_query, "SELECT * FROM custom_ignore")
    
    # This should not be ignored
    @tracker.send(:log_query, "SELECT * FROM users")
    
    logs = Thread.current[@tracker::THREAD_KEY]
    refute_includes logs[:read], 'pg_attribute'
    refute_includes logs[:read], 'custom_ignore'
    assert_includes logs[:read], 'users'
  end

  def test_case_insensitive_table_filtering
    @tracker.configure(ignored_tables: ['PG_ATTRIBUTE'])
    @tracker.start_tracking
    
    @tracker.send(:log_query, "SELECT * FROM pg_attribute")
    
    logs = Thread.current[@tracker::THREAD_KEY]
    refute_includes logs[:read], 'pg_attribute'
  end

  def test_detect_services_default_patterns
    @tracker.start_tracking
    
    logs = Thread.current[@tracker::THREAD_KEY]
    logs[:captured_logs] << "Redis connection established"
    logs[:captured_logs] << "Sidekiq job enqueued" 
    logs[:captured_logs] << "Honeybadger notification sent"
    logs[:captured_logs] << "Some other log"
    
    services = @tracker.send(:detect_services, logs[:captured_logs])
    assert_includes services, 'Redis'
    assert_includes services, 'Sidekiq'
    assert_includes services, 'Honeybadger'
    refute_includes services, 'Some other log'
  end

  def test_detect_services_custom_patterns
    @tracker.configure(services: [
      { name: "CustomService", pattern: /custom_service/i },
      { name: "PayPal", pattern: /paypal/i }
    ])
    @tracker.start_tracking
    
    logs = Thread.current[@tracker::THREAD_KEY]
    logs[:captured_logs] << "Custom_Service API call made"
    logs[:captured_logs] << "PayPal payment processed"
    logs[:captured_logs] << "Unknown service"
    
    services = @tracker.send(:detect_services, logs[:captured_logs])
    assert_includes services, 'CustomService'
    assert_includes services, 'PayPal'
    refute_includes services, 'Unknown service'
  end

  def test_format_summary_with_colors
    read_models = ['users', 'posts']
    write_models = ['comments']
    services = ['Redis']
    controller_action = 'UsersController#show'
    
    output = @tracker.send(:format_summary, read_models, write_models, services, controller_action, true)
    
    assert_includes output, 'UsersController#show'
    assert_includes output, 'users'
    assert_includes output, 'posts' 
    assert_includes output, 'comments'
    assert_includes output, 'Redis'
    assert_includes output, 'Models and Services accessed during request'
  end

  def test_format_summary_without_colors
    read_models = ['users']
    write_models = ['posts']
    services = ['Redis']
    
    output = @tracker.send(:format_summary, read_models, write_models, services, nil, false)
    
    # Should not contain ANSI escape codes
    refute_match(/\e\[\d+m/, output)
    assert_includes output, 'users'
    assert_includes output, 'posts'
    assert_includes output, 'Redis'
  end

  def test_format_summary_empty_data
    output = @tracker.send(:format_summary, [], [], [], 'TestController#index', false)
    
    assert_includes output, 'TestController#index'
    assert_includes output, 'No models or services accessed during this request'
  end

  def test_log_message
    @tracker.start_tracking
    
    @tracker.send(:log_message, "Test log message")
    
    logs = Thread.current[@tracker::THREAD_KEY]
    assert_includes logs[:captured_logs], "Test log message"
  end

  def test_controller_and_action_capture
    @tracker.start_tracking
    
    # Simulate process_action notification
    ActiveSupport::Notifications.instrument("process_action.action_controller", {
      controller: "UsersController",
      action: "show"
    })
    
    logs = Thread.current[@tracker::THREAD_KEY]
    assert_equal "UsersController", logs[:controller]
    assert_equal "show", logs[:action]
  end
end