# frozen_string_literal: true

require 'test_helper'
require 'json'
require 'tmpdir'

# rubocop:disable Metrics/ClassLength
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

    sql = 'SELECT * FROM users WHERE id = 1'
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
    @tracker.configure(ignored_tables: %w[pg_attribute custom_ignore])
    @tracker.start_tracking

    # These should be ignored
    @tracker.send(:log_query, 'SELECT * FROM pg_attribute')
    @tracker.send(:log_query, 'SELECT * FROM custom_ignore')

    # This should not be ignored
    @tracker.send(:log_query, 'SELECT * FROM users')

    logs = Thread.current[@tracker::THREAD_KEY]
    refute_includes logs[:read], 'pg_attribute'
    refute_includes logs[:read], 'custom_ignore'
    assert_includes logs[:read], 'users'
  end

  def test_case_insensitive_table_filtering
    @tracker.configure(ignored_tables: ['PG_ATTRIBUTE'])
    @tracker.start_tracking

    @tracker.send(:log_query, 'SELECT * FROM pg_attribute')

    logs = Thread.current[@tracker::THREAD_KEY]
    refute_includes logs[:read], 'pg_attribute'
  end

  def test_detect_services_default_patterns
    @tracker.start_tracking

    logs = Thread.current[@tracker::THREAD_KEY]
    logs[:captured_logs] << 'Redis connection established'
    logs[:captured_logs] << 'Sidekiq job enqueued'
    logs[:captured_logs] << 'Honeybadger notification sent'
    logs[:captured_logs] << 'Some other log'

    services = @tracker.send(:detect_services, logs[:captured_logs])
    assert_includes services, 'Redis'
    assert_includes services, 'Sidekiq'
    assert_includes services, 'Honeybadger'
    refute_includes services, 'Some other log'
  end

  def test_detect_services_custom_patterns
    @tracker.configure(services: [
                         { name: 'CustomService', pattern: /custom_service/i },
                         { name: 'PayPal', pattern: /paypal/i }
                       ])
    @tracker.start_tracking

    logs = Thread.current[@tracker::THREAD_KEY]
    logs[:captured_logs] << 'Custom_Service API call made'
    logs[:captured_logs] << 'PayPal payment processed'
    logs[:captured_logs] << 'Unknown service'

    services = @tracker.send(:detect_services, logs[:captured_logs])
    assert_includes services, 'CustomService'
    assert_includes services, 'PayPal'
    refute_includes services, 'Unknown service'
  end

  def test_format_summary_with_colors
    read_models = %w[users posts]
    write_models = ['comments']
    services = ['Redis']
    controller_action = 'UsersController#show'

    output = @tracker.send(:format_table_summary, read_models, write_models, services, controller_action, true)

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

    output = @tracker.send(:format_table_summary, read_models, write_models, services, nil, false)

    # Should not contain ANSI escape codes
    refute_match(/\e\[\d+m/, output)
    assert_includes output, 'users'
    assert_includes output, 'posts'
    assert_includes output, 'Redis'
  end

  def test_format_summary_empty_data
    output = @tracker.send(:format_table_summary, [], [], [], 'TestController#index', false)

    assert_includes output, 'TestController#index'
    assert_includes output, 'No models or services accessed during this request'
  end

  def test_format_csv_summary
    read_models = %w[users posts]
    write_models = ['comments']
    services = ['Redis']
    controller_action = 'UsersController#show'

    output = @tracker.send(:format_csv_summary, read_models, write_models, services, controller_action)

    lines = output.split("\n")
    header = lines[0]
    data = lines[1]

    assert_includes header, 'Action'
    assert_includes header, 'users'
    assert_includes header, 'posts'
    assert_includes header, 'comments'
    assert_includes header, 'Redis'

    assert_includes data, 'UsersController#show'
    assert_includes data, 'R' # users read
    assert_includes data, 'Y' # Redis accessed
  end

  def test_format_csv_summary_empty_data
    output = @tracker.send(:format_csv_summary, [], [], [], 'TestController#index')

    assert_includes output, 'Action'
    assert_includes output, 'No models or services accessed during this request'
  end

  def test_format_json_summary
    read_models = %w[users posts]
    write_models = ['comments']
    services = ['Redis']
    controller_action = 'UsersController#show'

    output = @tracker.send(:format_json_summary, read_models, write_models, services, controller_action)

    parsed = JSON.parse(output)

    assert_includes parsed.keys, 'UsersController#show'
    assert_equal %w[posts users], parsed['UsersController#show']['read'].sort
    assert_equal ['comments'], parsed['UsersController#show']['write']
    assert_equal ['Redis'], parsed['UsersController#show']['services']
  end

  def test_accumulate_json_data_new_action
    # Create temporary file
    temp_dir = Dir.mktmpdir
    temp_file = File.join(temp_dir, 'test_tracker.json')

    # Configure tracker with temporary file
    @tracker.configure(
      write_to_file: true,
      log_file_path: temp_file,
      print_format: :json
    )

    read_models = %w[users posts]
    write_models = ['comments']
    services = ['Redis']
    controller_action = 'UsersController#show'

    @tracker.send(:accumulate_json_data, read_models, write_models, services, controller_action)

    # Read the JSON file
    assert File.exist?(temp_file)
    json_content = File.read(temp_file)
    parsed = JSON.parse(json_content)

    assert_includes parsed.keys, 'UsersController#show'
    assert_equal %w[posts users], parsed['UsersController#show']['read']
    assert_equal ['comments'], parsed['UsersController#show']['write']
    assert_equal ['Redis'], parsed['UsersController#show']['services']
  ensure
    FileUtils.rm_rf(temp_dir) if temp_dir
  end

  def test_accumulate_json_data_merge_existing_action
    # Create temporary file
    temp_dir = Dir.mktmpdir
    temp_file = File.join(temp_dir, 'test_tracker.json')

    # Configure tracker with temporary file
    @tracker.configure(
      write_to_file: true,
      log_file_path: temp_file,
      print_format: :json
    )

    controller_action = 'UsersController#show'

    # First request
    @tracker.send(:accumulate_json_data, %w[users posts], ['comments'], ['Redis'], controller_action)

    # Second request with additional data
    @tracker.send(:accumulate_json_data, %w[posts profiles], ['posts'], ['Sidekiq'], controller_action)

    # Read the JSON file
    json_content = File.read(temp_file)
    parsed = JSON.parse(json_content)

    # Should contain merged data
    assert_includes parsed.keys, 'UsersController#show'
    assert_equal %w[posts profiles users], parsed['UsersController#show']['read'].sort
    assert_equal %w[comments posts], parsed['UsersController#show']['write'].sort
    assert_equal %w[Redis Sidekiq], parsed['UsersController#show']['services'].sort
  ensure
    FileUtils.rm_rf(temp_dir) if temp_dir
  end

  def test_accumulate_json_data_multiple_actions
    # Create temporary file
    temp_dir = Dir.mktmpdir
    temp_file = File.join(temp_dir, 'test_tracker.json')

    # Configure tracker with temporary file
    @tracker.configure(
      write_to_file: true,
      log_file_path: temp_file,
      print_format: :json
    )

    # First action
    @tracker.send(:accumulate_json_data, %w[users], [], ['Redis'], 'UsersController#show')

    # Second action
    @tracker.send(:accumulate_json_data, %w[posts], ['posts'], ['Sidekiq'], 'PostsController#create')

    # Read the JSON file
    json_content = File.read(temp_file)
    parsed = JSON.parse(json_content)

    # Should contain both actions
    assert_equal 2, parsed.keys.length
    assert_includes parsed.keys, 'UsersController#show'
    assert_includes parsed.keys, 'PostsController#create'

    assert_equal ['users'], parsed['UsersController#show']['read']
    assert_equal [], parsed['UsersController#show']['write']
    assert_equal ['Redis'], parsed['UsersController#show']['services']

    assert_equal ['posts'], parsed['PostsController#create']['read']
    assert_equal ['posts'], parsed['PostsController#create']['write']
    assert_equal ['Sidekiq'], parsed['PostsController#create']['services']
  ensure
    FileUtils.rm_rf(temp_dir) if temp_dir
  end

  def test_format_json_print_summary
    read_models = %w[users posts]
    write_models = ['comments']
    services = ['Redis']
    controller_action = 'UsersController#show'

    output = @tracker.send(:format_json_print_summary, read_models, write_models, services, controller_action)

    assert_includes output, 'UsersController#show:'
    assert_includes output, '"read":'
    assert_includes output, '"posts"'
    assert_includes output, '"users"'
    assert_includes output, '"write":'
    assert_includes output, '"comments"'
    assert_includes output, '"services":'
    assert_includes output, '"Redis"'
  end

  def test_generate_format_output_table
    read_models = %w[users posts]
    write_models = ['comments']
    services = ['Redis']
    controller_action = 'UsersController#show'

    summary_data = {
      read_models: read_models,
      write_models: write_models,
      services_accessed: services,
      controller_action: controller_action
    }

    colored_output, plain_output = @tracker.send(
      :generate_format_output, :table, summary_data, true
    )

    assert_includes colored_output, 'UsersController#show'
    assert_includes plain_output, 'UsersController#show'
    assert_includes colored_output, 'users'
    assert_includes plain_output, 'comments'
  end

  def test_generate_format_output_csv
    read_models = %w[users posts]
    write_models = ['comments']
    services = ['Redis']
    controller_action = 'UsersController#show'

    summary_data = {
      read_models: read_models,
      write_models: write_models,
      services_accessed: services,
      controller_action: controller_action
    }

    colored_output, plain_output = @tracker.send(
      :generate_format_output, :csv, summary_data, true
    )

    assert_equal colored_output, plain_output
    assert_includes colored_output, 'Action,comments,posts,users,Redis'
    assert_includes colored_output, 'UsersController#show'
  end

  def test_generate_format_output_json
    read_models = %w[users posts]
    write_models = ['comments']
    services = ['Redis']
    controller_action = 'UsersController#show'

    summary_data = {
      read_models: read_models,
      write_models: write_models,
      services_accessed: services,
      controller_action: controller_action
    }

    colored_output, plain_output = @tracker.send(
      :generate_format_output, :json, summary_data, true
    )

    assert_equal colored_output, plain_output
    assert_includes colored_output, 'UsersController#show:'
    assert_includes colored_output, '"read":'
    assert_includes colored_output, '"posts"'
    assert_includes colored_output, '"users"'
  end

  def test_separate_print_and_log_formats
    @tracker.configure(
      print_format: :json,
      log_format: :csv,
      print_to_rails_log: false, # Don't test log output here
      write_to_file: false # Don't test file output here
    )

    config = @tracker.config
    assert_equal :json, config[:print_format]
    assert_equal :csv, config[:log_format]
  end

  def test_log_format_defaults_to_print_format
    @tracker.configure(print_format: :csv)

    config = @tracker.config
    assert_equal :csv, config[:print_format]
    assert_equal :csv, config[:log_format]
  end

  def test_explicit_log_format_overrides_default
    @tracker.configure(
      print_format: :table,
      log_format: :json
    )

    config = @tracker.config
    assert_equal :table, config[:print_format]
    assert_equal :json, config[:log_format]
  end

  def test_json_accumulation_preserves_existing_data
    # Create temporary file
    temp_dir = Dir.mktmpdir
    temp_file = File.join(temp_dir, 'test_accumulation.json')

    # Configure tracker with temporary file
    @tracker.configure(
      write_to_file: true,
      log_file_path: temp_file,
      log_format: :json
    )

    # Write initial data to the file manually to simulate existing data
    initial_data = {
      'ExistingController#action' => {
        'read' => ['existing_table'],
        'write' => [],
        'services' => ['ExistingService']
      }
    }
    File.write(temp_file, JSON.pretty_generate(initial_data))

    # Now accumulate new data
    @tracker.send(:accumulate_json_data, %w[users posts], ['comments'], ['Redis'], 'UsersController#show')

    # Read the JSON file and verify both old and new data exist
    json_content = File.read(temp_file)
    parsed = JSON.parse(json_content)

    # Should contain both the existing and new data
    assert_equal 2, parsed.keys.length
    assert_includes parsed.keys, 'ExistingController#action'
    assert_includes parsed.keys, 'UsersController#show'

    # Verify existing data is preserved
    assert_equal ['existing_table'], parsed['ExistingController#action']['read']
    assert_equal [], parsed['ExistingController#action']['write']
    assert_equal ['ExistingService'], parsed['ExistingController#action']['services']

    # Verify new data is added
    assert_equal %w[posts users], parsed['UsersController#show']['read']
    assert_equal ['comments'], parsed['UsersController#show']['write']
    assert_equal ['Redis'], parsed['UsersController#show']['services']
  ensure
    FileUtils.rm_rf(temp_dir) if temp_dir
  end

  def test_format_csv_print_summary
    read_models = %w[users posts]
    write_models = ['comments']
    services = ['Redis']
    controller_action = 'UsersController#show'

    output = @tracker.send(:format_csv_print_summary, read_models, write_models, services, controller_action)

    lines = output.split("\n")
    header = lines[0]
    data = lines[1]

    assert_includes header, 'Action'
    assert_includes header, 'users'
    assert_includes header, 'posts'
    assert_includes header, 'comments'
    assert_includes header, 'Redis'

    assert_includes data, 'UsersController#show'
    assert_includes data, 'R' # users read
    assert_includes data, 'Y' # Redis accessed
  end

  def test_format_csv_print_summary_empty_data
    output = @tracker.send(:format_csv_print_summary, [], [], [], 'TestController#index')

    assert_includes output, 'TestController#index:'
    assert_includes output, 'No models or services accessed during this request'
  end

  def test_accumulate_csv_data_new_action
    # Create temporary file
    temp_dir = Dir.mktmpdir
    temp_file = File.join(temp_dir, 'test_tracker.csv')

    # Configure tracker with temporary file
    @tracker.configure(
      write_to_file: true,
      log_file_path: temp_file,
      log_format: :csv
    )

    read_models = %w[users posts]
    write_models = ['comments']
    services = ['Redis']
    controller_action = 'UsersController#show'

    @tracker.send(:accumulate_csv_data, read_models, write_models, services, controller_action)

    # Read the CSV file
    assert File.exist?(temp_file)
    csv_content = File.read(temp_file)
    lines = csv_content.split("\n")

    header = lines[0]
    data = lines[1]

    assert_includes header, 'Action'
    assert_includes header, 'users'
    assert_includes header, 'posts'
    assert_includes header, 'comments'
    assert_includes header, 'Redis'

    assert_includes data, 'UsersController#show'
    assert_includes data, 'R' # read access
    assert_includes data, 'W' # write access
    assert_includes data, 'Y' # service access
  ensure
    FileUtils.rm_rf(temp_dir) if temp_dir
  end

  def test_accumulate_csv_data_merge_existing_action
    # Create temporary file
    temp_dir = Dir.mktmpdir
    temp_file = File.join(temp_dir, 'test_tracker.csv')

    # Configure tracker with temporary file
    @tracker.configure(
      write_to_file: true,
      log_file_path: temp_file,
      log_format: :csv
    )

    controller_action = 'UsersController#show'

    # First request
    @tracker.send(:accumulate_csv_data, %w[users posts], ['comments'], ['Redis'], controller_action)

    # Second request with additional data for same action
    @tracker.send(:accumulate_csv_data, %w[posts profiles], ['users'], ['Sidekiq'], controller_action)

    # Read the CSV file
    csv_content = File.read(temp_file)
    lines = csv_content.split("\n")

    header = lines[0]
    data = lines[1]

    # Should contain merged headers
    %w[users posts comments profiles Redis Sidekiq].each do |name|
      assert_includes header, name
    end

    # Should contain merged data - users should be RW (was R, now also W)
    assert_includes data, 'UsersController#show'

    # Parse CSV properly to check specific values
    require 'csv'
    parsed = CSV.parse(csv_content, headers: true)
    row = parsed.first

    assert_equal 'RW', row['users'] # Was R, now R+W = RW
    assert_equal 'R', row['posts']  # Read access
    assert_equal 'W', row['comments'] # Write access
    assert_equal 'R', row['profiles'] # Read access from second request
    assert_equal 'Y', row['Redis'] # Service access
    assert_equal 'Y', row['Sidekiq'] # Service access from second request
  ensure
    FileUtils.rm_rf(temp_dir) if temp_dir
  end

  def test_accumulate_csv_data_multiple_actions
    # Create temporary file
    temp_dir = Dir.mktmpdir
    temp_file = File.join(temp_dir, 'test_tracker.csv')

    # Configure tracker with temporary file
    @tracker.configure(
      write_to_file: true,
      log_file_path: temp_file,
      log_format: :csv
    )

    # First action
    @tracker.send(:accumulate_csv_data, %w[users], [], ['Redis'], 'UsersController#show')

    # Second action
    @tracker.send(:accumulate_csv_data, %w[posts], ['posts'], ['Sidekiq'], 'PostsController#create')

    # Read the CSV file
    csv_content = File.read(temp_file)

    # Should have two data rows
    lines = csv_content.split("\n")
    assert_equal 3, lines.length # header + 2 data rows

    # Parse and verify both actions
    require 'csv'
    parsed = CSV.parse(csv_content, headers: true)

    users_row = parsed.find { |row| row['Action'] == 'UsersController#show' }
    posts_row = parsed.find { |row| row['Action'] == 'PostsController#create' }

    assert users_row
    assert posts_row

    assert_equal 'R', users_row['users']
    assert_equal 'Y', users_row['Redis']
    assert_equal '-', users_row['posts'] # Not accessed by this action

    assert_equal 'RW', posts_row['posts'] # Read and write
    assert_equal 'Y', posts_row['Sidekiq']
    assert_equal '-', posts_row['users'] # Not accessed by this action
  ensure
    FileUtils.rm_rf(temp_dir) if temp_dir
  end

  def test_csv_preserves_existing_data
    # Create temporary file
    temp_dir = Dir.mktmpdir
    temp_file = File.join(temp_dir, 'test_accumulation.csv')

    # Configure tracker with temporary file
    @tracker.configure(
      write_to_file: true,
      log_file_path: temp_file,
      log_format: :csv
    )

    # Write initial CSV data manually
    initial_csv = "Action,existing_table,ExistingService\nExistingController#action,R,Y\n"
    File.write(temp_file, initial_csv)

    # Now accumulate new data
    @tracker.send(:accumulate_csv_data, %w[users posts], ['comments'], ['Redis'], 'UsersController#show')

    # Read the CSV file and verify both old and new data exist
    csv_content = File.read(temp_file)
    require 'csv'
    parsed = CSV.parse(csv_content, headers: true)

    # Should contain both actions
    assert_equal 2, parsed.length

    existing_row = parsed.find { |row| row['Action'] == 'ExistingController#action' }
    new_row = parsed.find { |row| row['Action'] == 'UsersController#show' }

    assert existing_row
    assert new_row

    # Verify existing data is preserved
    assert_equal 'R', existing_row['existing_table']
    assert_equal 'Y', existing_row['ExistingService']

    # Verify new data is added
    assert_equal 'R', new_row['users']
    assert_equal 'W', new_row['comments']
    assert_equal 'Y', new_row['Redis']
  ensure
    FileUtils.rm_rf(temp_dir) if temp_dir
  end

  def test_log_message
    @tracker.start_tracking

    @tracker.send(:log_message, 'Test log message')

    logs = Thread.current[@tracker::THREAD_KEY]
    assert_includes logs[:captured_logs], 'Test log message'
  end

  def test_controller_and_action_capture
    @tracker.start_tracking

    # Simulate process_action notification
    ActiveSupport::Notifications.instrument('process_action.action_controller', {
                                              controller: 'UsersController',
                                              action: 'show'
                                            })

    logs = Thread.current[@tracker::THREAD_KEY]
    assert_equal 'UsersController', logs[:controller]
    assert_equal 'show', logs[:action]
  end

  def test_should_ignore_controller_action_with_ignored_controllers
    @tracker.configure(ignored_controllers: ['Rails::PwaController', 'HealthController'])

    # Should ignore entire controllers
    assert @tracker.send(:should_ignore_controller_action?, 'Rails::PwaController', 'manifest')
    assert @tracker.send(:should_ignore_controller_action?, 'HealthController', 'check')

    # Should not ignore other controllers
    refute @tracker.send(:should_ignore_controller_action?, 'UsersController', 'show')
  end

  def test_should_ignore_controller_action_with_specific_actions
    @tracker.configure(ignored_actions: {
                         'ApplicationController' => %w[ping status],
                         'ApiController' => ['heartbeat']
                       })

    # Should ignore specific actions
    assert @tracker.send(:should_ignore_controller_action?, 'ApplicationController', 'ping')
    assert @tracker.send(:should_ignore_controller_action?, 'ApplicationController', 'status')
    assert @tracker.send(:should_ignore_controller_action?, 'ApiController', 'heartbeat')

    # Should not ignore other actions
    refute @tracker.send(:should_ignore_controller_action?, 'ApplicationController', 'index')
    refute @tracker.send(:should_ignore_controller_action?, 'ApiController', 'show')
    refute @tracker.send(:should_ignore_controller_action?, 'UsersController', 'ping')
  end

  def test_should_ignore_controller_action_with_empty_array_ignores_controller
    @tracker.configure(ignored_actions: {
                         'Rails::PwaController' => [], # Empty array = ignore entire controller
                         'HealthController' => nil     # nil = ignore entire controller
                       })

    # Should ignore entire controllers
    assert @tracker.send(:should_ignore_controller_action?, 'Rails::PwaController', 'manifest')
    assert @tracker.send(:should_ignore_controller_action?, 'Rails::PwaController', 'any_action')
    assert @tracker.send(:should_ignore_controller_action?, 'HealthController', 'check')
    assert @tracker.send(:should_ignore_controller_action?, 'HealthController', 'status')

    # Should not ignore other controllers
    refute @tracker.send(:should_ignore_controller_action?, 'UsersController', 'show')
  end

  def test_should_ignore_controller_action_with_global_actions
    @tracker.configure(ignored_actions: {
                         '' => %w[ping health status] # Global actions to ignore
                       })

    # Should ignore these actions from any controller
    assert @tracker.send(:should_ignore_controller_action?, 'ApplicationController', 'ping')
    assert @tracker.send(:should_ignore_controller_action?, 'UsersController', 'health')
    assert @tracker.send(:should_ignore_controller_action?, 'ApiController', 'status')
    assert @tracker.send(:should_ignore_controller_action?, 'AnyController', 'ping')

    # Should not ignore other actions
    refute @tracker.send(:should_ignore_controller_action?, 'UsersController', 'show')
    refute @tracker.send(:should_ignore_controller_action?, 'ApplicationController', 'index')
  end

  def test_should_ignore_controller_action_with_combined_patterns
    @tracker.configure(
      ignored_controllers: ['Rails::PwaController'],
      ignored_actions: {
        '' => ['ping'],                                     # Global ignore
        'ApplicationController' => ['status'],              # Controller-specific
        'MonitoringController' => [],                       # Ignore entire controller
        'ApiController' => %w[heartbeat version] # Multiple specific actions
      }
    )

    # Test ignored_controllers
    assert @tracker.send(:should_ignore_controller_action?, 'Rails::PwaController', 'manifest')

    # Test global actions
    assert @tracker.send(:should_ignore_controller_action?, 'UsersController', 'ping')
    assert @tracker.send(:should_ignore_controller_action?, 'ApiController', 'ping')

    # Test controller-specific actions
    assert @tracker.send(:should_ignore_controller_action?, 'ApplicationController', 'status')
    refute @tracker.send(:should_ignore_controller_action?, 'UsersController', 'status')

    # Test entire controller ignore with empty array
    assert @tracker.send(:should_ignore_controller_action?, 'MonitoringController', 'any_action')

    # Test multiple specific actions
    assert @tracker.send(:should_ignore_controller_action?, 'ApiController', 'heartbeat')
    assert @tracker.send(:should_ignore_controller_action?, 'ApiController', 'version')
    refute @tracker.send(:should_ignore_controller_action?, 'ApiController', 'show')

    # Test actions that should not be ignored
    refute @tracker.send(:should_ignore_controller_action?, 'UsersController', 'show')
    refute @tracker.send(:should_ignore_controller_action?, 'ApplicationController', 'index')
  end

  def test_should_ignore_controller_action_no_config
    # Should not ignore anything when no config is set
    refute @tracker.send(:should_ignore_controller_action?, 'UsersController', 'show')
  end

  def test_should_ignore_controller_action_missing_params
    @tracker.configure(ignored_controllers: ['TestController'])

    # Should return false for missing controller or action
    refute @tracker.send(:should_ignore_controller_action?, nil, 'show')
    refute @tracker.send(:should_ignore_controller_action?, 'UsersController', nil)
    refute @tracker.send(:should_ignore_controller_action?, nil, nil)
  end
end
# rubocop:enable Metrics/ClassLength
