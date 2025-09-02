# Contributing to RailsActionTracker

First off, thank you for considering contributing to RailsActionTracker! 🎉

The following is a set of guidelines for contributing to this project. These are mostly guidelines, not rules. Use your best judgment, and feel free to propose changes to this document in a pull request.

## Code of Conduct

This project and everyone participating in it is governed by our commitment to creating a welcoming environment. By participating, you are expected to uphold this standard.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing issues list as you might find out that you don't need to create one. When you are creating a bug report, please include as many details as possible:

**Use a clear and descriptive title** for the issue to identify the problem.

**Describe the exact steps which reproduce the problem** in as many details as possible.

**Include these details:**
- Ruby version (`ruby -v`)
- Rails version
- Gem version
- Operating system
- Complete error message and stack trace
- Sample code that reproduces the issue

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, please include:

- **Use a clear and descriptive title**
- **Provide a step-by-step description** of the suggested enhancement
- **Explain why this enhancement would be useful**
- **Include examples** of how the enhancement would be used

### Pull Requests

1. Fork the repo and create your branch from `master`
2. If you've added code that should be tested, add tests
3. If you've changed APIs, update the documentation
4. Ensure the test suite passes
5. Make sure your code lints
6. Issue that pull request!

## Development Process

### Setting Up Development Environment

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/rails_action_tracker.git
cd rails_action_tracker

# Install dependencies
bundle install

# Set up Appraisal for multi-Rails testing
bundle exec appraisal install
```

### Testing

**Always run the full test suite before submitting:**

```bash
# Quick test with current Ruby/Rails
bundle exec rake test

# Test all Rails versions
./script/test-all

# Check code style
bundle exec rubocop
```

**When adding new features:**
- Add tests that cover the new functionality
- Test edge cases and error conditions
- Update integration tests if needed

**Test categories:**
- Unit tests (`test/test_tracker.rb`)
- Integration tests (`test/test_integration.rb`)
- Middleware tests (`test/test_middleware.rb`)
- Configuration tests (`test/test_configuration.rb`)

### Code Style

We use RuboCop for code style enforcement:

```bash
# Check for style issues
bundle exec rubocop

# Auto-fix what can be fixed automatically
bundle exec rubocop -a
```

**Key style guidelines:**
- Use 2 spaces for indentation
- Keep lines under 120 characters
- Use meaningful variable and method names
- Add comments for complex logic
- Follow Ruby community conventions

### Commit Messages

Write clear, concise commit messages:

```
Add feature to track custom service patterns

- Allow users to define custom regex patterns for service detection
- Add configuration option `custom_services` 
- Include tests for custom pattern matching
- Update documentation with examples

Closes #123
```

**Format:**
- Use the present tense ("Add feature" not "Added feature")
- Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit the first line to 72 characters or less
- Reference issues and pull requests liberally after the first line

### Documentation

When changing functionality:
- Update the README.md if needed
- Update code comments
- Add examples for new features
- Update CHANGELOG.md

### Branching Strategy

- `master` - main development branch
- Feature branches - `feature/your-feature-name`
- Bug fixes - `fix/issue-description`
- Documentation - `docs/what-you-updated`

## Testing Guidelines

### Writing Tests

**Test structure:**
```ruby
def test_descriptive_name_of_what_is_being_tested
  # Arrange - set up test data
  tracker = RailsActionTracker::Tracker
  tracker.configure(option: value)
  
  # Act - perform the action being tested
  result = tracker.some_method(input)
  
  # Assert - verify the expected outcome
  assert_equal expected_value, result
  assert_includes collection, item
end
```

**Test naming:**
- Use descriptive names that explain the scenario
- Include the expected behavior
- Example: `test_ignores_tables_case_insensitively`

**What to test:**
- Happy path scenarios
- Edge cases and boundary conditions  
- Error conditions and exception handling
- Configuration changes
- Thread safety (where applicable)

### Rails Version Compatibility

When making changes, consider:
- Will this work across all supported Rails versions?
- Are there Rails version-specific APIs being used?
- Test with both oldest and newest supported versions

### Running Specific Tests

```bash
# Run single test file
bundle exec ruby -Ilib:test test/test_tracker.rb

# Run specific test method
bundle exec ruby -Ilib:test test/test_tracker.rb -n test_specific_method

# Run with verbose output
bundle exec rake test TESTOPTS="-v"
```

## Release Process

(For maintainers)

1. **Prepare release:**
   ```bash
   # Update version in lib/rails_action_tracker/version.rb
   # Update CHANGELOG.md with changes
   git commit -am "Prepare release v0.x.x"
   ```

2. **Test thoroughly:**
   ```bash
   ./script/test-all
   bundle exec rubocop
   ```

3. **Create release:**
   ```bash
   git tag v0.x.x
   git push origin master --tags
   bundle exec rake release
   ```

## Getting Help

- Create an issue for bugs or feature requests
- Check existing issues and discussions
- Look at the test suite for examples of usage

## Recognition

Contributors will be recognized in:
- Git commit history
- GitHub contributors list  
- Release notes for significant contributions

Thank you for contributing! 🚀