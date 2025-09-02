# Contributing to RailsActionTracker

We welcome contributions to RailsActionTracker! This document provides guidelines for contributing to the project.

## Getting Started

Before contributing, please:
1. Read this document completely
2. Check existing issues and pull requests
3. Set up your development environment (see [DEVELOPMENT.md](DEVELOPMENT.md))

## Types of Contributions

### Bug Reports
- **Search existing issues** first to avoid duplicates
- **Use the issue template** if available
- **Provide clear steps to reproduce** the bug
- **Include relevant system information** (Ruby version, Rails version, gem version)
- **Add error messages** and stack traces when applicable

### Feature Requests
- **Explain the use case** for your proposed feature
- **Provide examples** of how it would be used
- **Consider backward compatibility** implications
- **Discuss implementation approach** if you have ideas

### Code Contributions
- **Fork the repository** and create a feature branch
- **Follow coding standards** (see Code Style section below)
- **Write comprehensive tests** for your changes
- **Update documentation** when needed
- **Ensure CI passes** before submitting

## Development Process

### 1. Fork and Clone
```bash
git clone https://github.com/YOUR_USERNAME/rails_action_tracker.git
cd rails_action_tracker
```

### 2. Create Feature Branch
```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/issue-description
```

### 3. Make Changes
- Follow the coding standards outlined below
- Write or update tests for your changes
- Update documentation if needed

### 4. Test Your Changes
```bash
# Run the full test suite
bundle exec rake test

# Test against multiple Rails versions
./script/test-all

# Check code style
bundle exec rubocop
```

### 5. Submit Pull Request
- **Write a clear title** and description
- **Reference related issues** using keywords like "Closes #123"
- **Explain your changes** and why they're needed
- **Include screenshots** for UI changes (if applicable)

## Code Style

### Ruby Style Guide
We use RuboCop to enforce code style. Key points:
- **Use single quotes** for string literals
- **2 spaces** for indentation
- **Line length**: 120 characters maximum
- **Follow Ruby community conventions**

### Testing Standards
- **Write tests** for all new functionality
- **Update existing tests** when modifying behavior
- **Use descriptive test names** that explain what is being tested
- **Follow existing test patterns** in the codebase

### Documentation Standards
- **Update README.md** for user-facing changes
- **Add inline comments** for complex logic
- **Update CHANGELOG.md** for notable changes
- **Use clear, concise language**

## Commit Guidelines

### Commit Messages
Follow these guidelines for commit messages:
- **Use present tense** ("Add feature" not "Added feature")
- **Use imperative mood** ("Move cursor to..." not "Moves cursor to...")
- **Limit first line to 72 characters**
- **Reference issues and pull requests** when applicable

### Examples
```
Add support for custom service detection patterns

- Allow users to specify custom regex patterns for service detection
- Update configuration documentation
- Add comprehensive tests

Closes #123
```

## Review Process

### What to Expect
- **All PRs require review** before merging
- **Automated tests** must pass
- **Code style checks** must pass
- **Maintainer feedback** may require changes

### How to Address Feedback
- **Respond to all comments** even if just to acknowledge
- **Make requested changes** in new commits (don't force push)
- **Ask for clarification** if feedback is unclear
- **Be patient and respectful** during the review process

## Release Process

Releases are handled by maintainers:
1. Version bump in `lib/rails_action_tracker/version.rb`
2. Update `CHANGELOG.md` with changes
3. Create git tag and push to GitHub
4. Build and push gem to RubyGems

## Code of Conduct

### Our Pledge
We are committed to providing a friendly, safe, and welcoming environment for all contributors.

### Expected Behavior
- **Be respectful** and inclusive
- **Accept constructive feedback** gracefully
- **Focus on what's best** for the community
- **Show empathy** towards other community members

### Unacceptable Behavior
- **Harassment** of any form
- **Discriminatory language** or behavior
- **Personal attacks** or trolling
- **Publishing private information** without consent

## Getting Help

### Resources
- **Documentation**: Check README.md and other docs first
- **Development Setup**: See [DEVELOPMENT.md](DEVELOPMENT.md)
- **Issues**: Search existing issues for similar problems
- **Discussions**: Use GitHub Discussions for questions

### Contact
- **GitHub Issues**: For bugs and feature requests
- **GitHub Discussions**: For general questions
- **Email**: For security issues or private matters

## Recognition

Contributors are recognized in:
- **CHANGELOG.md** for notable contributions
- **GitHub contributors page** automatically
- **Release notes** for significant features

Thank you for contributing to RailsActionTracker! 🎉
