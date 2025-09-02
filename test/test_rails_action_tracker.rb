# frozen_string_literal: true

require 'test_helper'

class TestRailsActionTracker < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::RailsActionTracker::VERSION
  end

  def test_module_constants_exist
    assert defined?(RailsActionTracker::Tracker)
    assert defined?(RailsActionTracker::Middleware)
    assert defined?(RailsActionTracker::Error)
  end

  def test_tracker_responds_to_main_methods
    tracker = RailsActionTracker::Tracker
    assert_respond_to tracker, :configure
    assert_respond_to tracker, :start_tracking
    assert_respond_to tracker, :stop_tracking
    assert_respond_to tracker, :print_summary
  end
end
