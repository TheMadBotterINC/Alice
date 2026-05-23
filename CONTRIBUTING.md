# Contributing to Alice

Thank you for your interest in contributing to Alice! We welcome contributions from the community and are excited to see what you'll build.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Development Setup](#development-setup)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Pull Request Process](#pull-request-process)
- [Community](#community)

---

## 🤝 Code of Conduct

By participating in this project, you agree to maintain a welcoming and inclusive environment for all contributors. Be respectful, constructive, and collaborative.

### Our Standards

- Use welcoming and inclusive language
- Be respectful of differing viewpoints
- Accept constructive criticism gracefully
- Focus on what's best for the community
- Show empathy towards other community members

---

## 🚀 Getting Started

### Prerequisites

Before you begin, ensure you have:

- Ruby 3.4.7+ (via `mise` or `rbenv`)
- PostgreSQL 16+
- Node.js 18+ and Yarn
- Redis (for background jobs)
- Git

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/alice.git
   cd alice
   ```
3. Add upstream remote:
   ```bash
   git remote add upstream https://github.com/ORIGINAL_OWNER/alice.git
   ```

---

## 💡 How to Contribute

### Reporting Bugs

Found a bug? Please create an issue with:

- **Clear title** - Describe the issue concisely
- **Steps to reproduce** - Detailed steps to reproduce the behavior
- **Expected behavior** - What you expected to happen
- **Actual behavior** - What actually happened
- **Environment** - Ruby version, Rails version, OS, browser
- **Screenshots** - If applicable

### Suggesting Features

Have an idea? We'd love to hear it! Create an issue with:

- **Feature description** - What problem does this solve?
- **Use case** - Real-world examples of how it would be used
- **Mockups** - UI mockups or wireframes if applicable
- **Implementation ideas** - Technical approach (optional)

### Code Contributions

We accept contributions for:

- Bug fixes
- New connectors (MySQL, SQL Server, BigQuery, etc.)
- UI/UX improvements
- Documentation improvements
- Performance optimizations
- Test coverage improvements
- New features (discuss in an issue first!)

---

## 🛠️ Development Setup

### Initial Setup

```bash
# Install dependencies
bundle install
yarn install

# Setup database
bin/rails db:create db:migrate db:seed

# Run the test suite
bin/rails test

# Start development server
bin/dev
```

The app will be available at `http://localhost:3000`

Default credentials:
- Admin: `admin@alice.example` / `password123`
- Viewer: `viewer@alice.example` / `password123`

### Database Management

```bash
# Reset database
bin/rails db:reset

# Run migrations
bin/rails db:migrate

# Rollback last migration
bin/rails db:rollback

# Seed with demo data
bin/rails db:seed
```

### Asset Compilation

```bash
# Precompile assets
bin/rails assets:precompile

# Watch and rebuild CSS (Tailwind)
yarn build:css --watch
```

---

## 📝 Coding Standards

### Ruby Style

We follow standard Ruby conventions:

- 2-space indentation
- Snake_case for methods and variables
- CamelCase for classes and modules
- Use descriptive variable names
- Keep methods short and focused

### Rails Conventions

- Follow RESTful routing conventions
- Use strong parameters for mass assignment
- Keep controllers thin, models fat
- Use concerns for shared behavior
- Write database-agnostic queries

### JavaScript Style

- Use modern ES6+ syntax
- Stimulus controllers for interactivity
- Keep controllers focused and composable
- Use data attributes for configuration
- Avoid jQuery

### CSS Style

- Use Tailwind utility classes
- Follow mobile-first approach
- Use responsive design patterns
- Keep custom CSS minimal

---

## 🧪 Testing

### Running Tests

```bash
# Run all tests
bin/rails test

# Run specific test file
bin/rails test test/models/pipeline_test.rb

# Run specific test
bin/rails test test/models/pipeline_test.rb:42
```

### Writing Tests

- Write tests for all new features
- Maintain or improve test coverage
- Use factories or fixtures appropriately
- Test edge cases and error conditions
- Use descriptive test names

Example test structure:

```ruby
require "test_helper"

class MyFeatureTest < ActiveSupport::TestCase
  def setup
    @user = users(:admin_user)
    @pipeline = pipelines(:one)
  end

  test "should do something meaningful" do
    # Arrange
    connector = Connector.create!(name: "Test", connector_type: "snowflake", config: {})
    
    # Act
    result = connector.test_connection
    
    # Assert
    assert result
    assert connector.connected?
  end
end
```

---

## 🔄 Pull Request Process

### Before Submitting

1. **Create a feature branch** from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** following coding standards

3. **Write or update tests** to cover your changes

4. **Run the test suite** and ensure all tests pass:
   ```bash
   bin/rails test
   ```

5. **Update documentation** if needed (README, inline comments, etc.)

6. **Commit your changes** with clear messages:
   ```bash
   git commit -m "Add feature: brief description"
   ```

### Commit Message Guidelines

Follow conventional commit format:

```
type: Brief description (50 chars or less)

More detailed explanation if needed (wrap at 72 chars).

- Bullet points are okay
- Use imperative mood: "Add" not "Added" or "Adds"

Fixes #123
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

### Submitting

1. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

2. **Create a Pull Request** on GitHub with:
   - Clear title describing the change
   - Description of what and why
   - Link to related issues
   - Screenshots for UI changes
   - Test results or coverage changes

3. **Respond to feedback** from maintainers

4. **Keep your branch updated** with main:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

### Review Process

- At least one maintainer will review your PR
- Address any requested changes
- Keep discussions respectful and constructive
- Be patient - reviews may take a few days

---

## 🌟 Community

### Get Help

- **GitHub Issues** - Bug reports and feature requests
- **GitHub Discussions** - Questions and community chat
- **Wiki** - Documentation and guides

### Stay Updated

- Watch the repository for notifications
- Follow release notes for new versions
- Check the roadmap for upcoming features

### Recognition

Contributors will be:
- Listed in release notes
- Acknowledged in the README
- Given credit in documentation

---

## 📄 License

By contributing to Alice, you agree that your contributions will be licensed under the Apache License 2.0.

---

Thank you for contributing to Alice! Your efforts help make data pipelines more accessible to everyone. 🚀
