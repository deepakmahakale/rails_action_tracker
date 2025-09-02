require 'rails/generators/base'

module RailsActionTracker
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)
      
      desc "Install RailsActionTracker configuration"

      def create_initializer_file
        template "initializer.rb", "config/initializers/rails_action_tracker.rb"
      end

      private

      def file_name
        "rails_action_tracker"
      end
    end
  end
end