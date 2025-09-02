module RailsActionTracker
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      return @app.call(env) unless should_track?(env)

      Tracker.start_tracking
      
      begin
        response = @app.call(env)
        Tracker.print_summary
        response
      ensure
        Tracker.stop_tracking
      end
    end

    private

    def should_track?(env)
      request = ActionDispatch::Request.new(env)
      
      # Skip tracking for assets, health checks, etc.
      return false if request.path.start_with?('/assets', '/health', '/favicon')
      return false if request.path.end_with?('.js', '.css', '.png', '.jpg', '.gif', '.ico')
      
      # Only track if Rails is defined and it's not a test environment
      defined?(Rails) && !Rails.env.test?
    end
  end
end