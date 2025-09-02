# frozen_string_literal: true

require "test_helper"

class TestMiddleware < Minitest::Test
  def setup
    @app = ->(env) { [200, {}, ['OK']] }
    @middleware = RailsActionTracker::Middleware.new(@app)
    @tracker = RailsActionTracker::Tracker
  end

  def teardown
    # Don't call stop_tracking in teardown for middleware tests
    # as it interferes with mock expectations
  end

  def test_middleware_calls_app
    env = { 'REQUEST_METHOD' => 'GET', 'PATH_INFO' => '/users' }
    
    response = @middleware.call(env)
    
    assert_equal [200, {}, ['OK']], response
  end

  def test_middleware_tracks_requests
    # Set Rails to non-test environment temporarily
    original_env = Rails.env
    Rails.env = ActiveSupport::StringInquirer.new("development")
    
    env = { 
      'REQUEST_METHOD' => 'GET', 
      'PATH_INFO' => '/users',
      'rack.input' => StringIO.new
    }
    
    @tracker.expects(:start_tracking).once
    @tracker.expects(:print_summary).once
    @tracker.expects(:stop_tracking).once
    
    @middleware.call(env)
  ensure
    Rails.env = original_env
  end

  def test_middleware_skips_assets
    env = { 
      'REQUEST_METHOD' => 'GET', 
      'PATH_INFO' => '/assets/application.js',
      'rack.input' => StringIO.new
    }
    
    @tracker.expects(:start_tracking).never
    @tracker.expects(:print_summary).never
    @tracker.expects(:stop_tracking).never
    
    @middleware.call(env)
  end

  def test_middleware_skips_health_checks
    env = { 
      'REQUEST_METHOD' => 'GET', 
      'PATH_INFO' => '/health',
      'rack.input' => StringIO.new
    }
    
    @tracker.expects(:start_tracking).never
    
    @middleware.call(env)
  end

  def test_middleware_skips_static_files
    %w[.js .css .png .jpg .gif .ico].each do |ext|
      env = { 
        'REQUEST_METHOD' => 'GET', 
        'PATH_INFO' => "/file#{ext}",
        'rack.input' => StringIO.new
      }
      
      @tracker.expects(:start_tracking).never
      
      @middleware.call(env)
    end
  end

  def test_middleware_handles_exceptions
    # Set Rails to non-test environment temporarily
    original_env = Rails.env
    Rails.env = ActiveSupport::StringInquirer.new("development")
    
    failing_app = ->(env) { raise "Something went wrong" }
    middleware = RailsActionTracker::Middleware.new(failing_app)
    
    env = { 
      'REQUEST_METHOD' => 'GET', 
      'PATH_INFO' => '/users',
      'rack.input' => StringIO.new
    }
    
    @tracker.expects(:start_tracking).once
    @tracker.expects(:stop_tracking).once
    
    assert_raises(RuntimeError) do
      middleware.call(env)
    end
  ensure
    Rails.env = original_env
  end

  def test_should_track_returns_false_for_test_env
    # The test helper sets Rails.env to "test"
    env = { 
      'REQUEST_METHOD' => 'GET', 
      'PATH_INFO' => '/users',
      'rack.input' => StringIO.new
    }
    
    should_track = @middleware.send(:should_track?, env)
    assert_equal false, should_track
  end

  def test_should_track_returns_false_for_assets
    env = { 
      'REQUEST_METHOD' => 'GET', 
      'PATH_INFO' => '/assets/application.css',
      'rack.input' => StringIO.new
    }
    
    should_track = @middleware.send(:should_track?, env)
    assert_equal false, should_track
  end

  def test_should_track_returns_false_for_favicon
    env = { 
      'REQUEST_METHOD' => 'GET', 
      'PATH_INFO' => '/favicon.ico',
      'rack.input' => StringIO.new
    }
    
    should_track = @middleware.send(:should_track?, env)
    assert_equal false, should_track
  end
end