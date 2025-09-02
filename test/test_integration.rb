# frozen_string_literal: true

require 'test_helper'
require 'tempfile'

class TestIntegration < Minitest::Test
  def setup
    @tracker = RailsActionTracker::Tracker
    @tracker.config = nil
    @tracker.custom_logger = nil
  end

  def teardown
    @tracker.stop_tracking
    @tracker.config = nil
    @tracker.custom_logger = nil
  end

  def test_full_tracking_workflow
    @tracker.configure(print_to_rails_log: false)
    @tracker.start_tracking

    # Simulate SQL queries
    simulate_sql_query('SELECT * FROM users WHERE id = 1')
    simulate_sql_query('SELECT * FROM posts WHERE user_id = 1')
    simulate_sql_query("INSERT INTO audit_logs (action) VALUES ('view')")
    simulate_sql_query('UPDATE user_sessions SET last_seen = NOW() WHERE id = 1')

    # Simulate service calls
    simulate_service_log('Redis connection established')
    simulate_service_log('Sidekiq job enqueued for user notification')

    # Simulate controller action
    simulate_controller_action('UsersController', 'show')

    logs = @tracker.stop_tracking

    # Verify collected data
    assert_includes logs[:read], 'users'
    assert_includes logs[:read], 'posts'
    assert_includes logs[:write], 'audit_logs'
    assert_includes logs[:write], 'user_sessions'

    assert_equal 'UsersController', logs[:controller]
    assert_equal 'show', logs[:action]

    assert(logs[:captured_logs].any? { |log| log.include?('Redis') })
    assert(logs[:captured_logs].any? { |log| log.include?('Sidekiq') })
  end

  def test_ignored_tables_in_workflow
    @tracker.configure(
      ignored_tables: %w[pg_attribute audit_logs],
      print_to_rails_log: false
    )
    @tracker.start_tracking

    # These should be ignored
    simulate_sql_query("SELECT * FROM pg_attribute WHERE attname = 'id'")
    simulate_sql_query("INSERT INTO audit_logs (action) VALUES ('test')")

    # This should be tracked
    simulate_sql_query('SELECT * FROM users WHERE id = 1')

    logs = @tracker.stop_tracking

    refute_includes logs[:read], 'pg_attribute'
    refute_includes logs[:write], 'audit_logs'
    assert_includes logs[:read], 'users'
  end

  def test_logging_to_rails_logger
    rails_logger_output = StringIO.new
    Rails.logger = Logger.new(rails_logger_output)

    @tracker.configure(print_to_rails_log: true)
    @tracker.start_tracking

    simulate_sql_query('SELECT * FROM users WHERE id = 1')
    simulate_controller_action('UsersController', 'show')

    @tracker.print_summary

    log_output = rails_logger_output.string
    assert_includes log_output, 'UsersController#show'
    assert_includes log_output, 'Models and Services accessed during request'
    assert_includes log_output, 'users'
  end

  def test_logging_to_custom_file
    temp_file = Tempfile.new('integration_test_log')
    log_path = temp_file.path
    temp_file.close

    @tracker.configure(
      print_to_rails_log: false,
      write_to_file: true,
      log_file_path: log_path
    )

    @tracker.start_tracking

    simulate_sql_query('SELECT * FROM posts WHERE published = true')
    simulate_controller_action('PostsController', 'index')

    @tracker.print_summary

    log_content = File.read(log_path)
    assert_includes log_content, 'PostsController#index'
    assert_includes log_content, 'posts'

    # Custom file should not have ANSI color codes
    refute_match(/\e\[\d+m/, log_content)

    # Clean up
    File.unlink(log_path) if File.exist?(log_path)
  end

  def test_logging_to_both_destinations
    rails_logger_output = StringIO.new
    Rails.logger = Logger.new(rails_logger_output)

    temp_file = Tempfile.new('dual_log_test')
    log_path = temp_file.path
    temp_file.close

    @tracker.configure(
      print_to_rails_log: true,
      write_to_file: true,
      log_file_path: log_path
    )

    @tracker.start_tracking

    simulate_sql_query('SELECT * FROM comments WHERE post_id = 1')
    simulate_controller_action('CommentsController', 'show')

    @tracker.print_summary

    # Check Rails logger output
    rails_output = rails_logger_output.string
    assert_includes rails_output, 'CommentsController#show'
    assert_includes rails_output, 'comments'

    # Check custom file output
    file_content = File.read(log_path)
    assert_includes file_content, 'CommentsController#show'
    assert_includes file_content, 'comments'

    # Clean up
    File.unlink(log_path) if File.exist?(log_path)
  end

  def test_service_detection_workflow
    @tracker.configure(
      services: [
        { name: 'CustomAPI', pattern: /custom_api/i },
        { name: 'PaymentGateway', pattern: /payment|stripe/i }
      ],
      print_to_rails_log: false
    )

    @tracker.start_tracking

    simulate_service_log('Custom_API request sent to external service')
    simulate_service_log('Payment processed via Stripe gateway')
    simulate_service_log('Unknown service call')

    logs = @tracker.stop_tracking

    services = @tracker.send(:detect_services, logs[:captured_logs])
    assert_includes services, 'CustomAPI'
    assert_includes services, 'PaymentGateway'
    refute_includes services, 'Unknown service call'
  end

  def test_empty_tracking_session
    rails_logger_output = StringIO.new
    Rails.logger = Logger.new(rails_logger_output)

    @tracker.configure(print_to_rails_log: true)
    @tracker.start_tracking

    simulate_controller_action('HomeController', 'index')

    @tracker.print_summary

    log_output = rails_logger_output.string
    assert_includes log_output, 'HomeController#index'
    assert_includes log_output, 'No models or services accessed during this request'
  end

  private

  def simulate_sql_query(sql)
    ActiveSupport::Notifications.instrument('sql.active_record', sql: sql)
  end

  def simulate_service_log(message)
    @tracker.send(:log_message, message)
  end

  def simulate_controller_action(controller, action)
    ActiveSupport::Notifications.instrument('process_action.action_controller', {
                                              controller: controller,
                                              action: action
                                            })
  end
end
