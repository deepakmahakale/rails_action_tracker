# frozen_string_literal: true

require_relative "lib/rails_action_tracker/version"

Gem::Specification.new do |spec|
  spec.name = "rails_action_tracker"
  spec.version = RailsActionTracker::VERSION
  spec.authors = ["Deepak Mahakale"]
  spec.email = ["deepakmahakale@gmail.com"]

  spec.summary = "Track ActiveRecord model operations and service usage during Rails action calls"
  spec.description = "A Rails gem that provides detailed tracking of model read/write operations and service usage during controller action execution, with configurable logging options."
  spec.homepage = "https://github.com/deepakmahakale/rails_action_tracker"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/deepakmahakale/rails_action_tracker"
  spec.metadata["changelog_uri"] = "https://github.com/deepakmahakale/rails_action_tracker/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Dependencies
  spec.add_dependency "activesupport", ">= 5.0"
  spec.add_dependency "actionpack", ">= 5.0"  # For ActionDispatch::Request
  spec.add_dependency "railties", ">= 5.0"   # For Rails::Railtie
  
  # Development dependencies
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "appraisal", "~> 2.4"
  spec.add_development_dependency "sqlite3", "~> 1.4"
  spec.add_development_dependency "mocha", "~> 2.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
