# Contributing to ScanImage Z-Control (Foilview)

Thank you for your interest in contributing to the Foilview project! This document provides guidelines and information for contributors.

## Getting Started

### Prerequisites
- MATLAB R2020b or later
- Git for version control
- Basic understanding of MATLAB app development
- Familiarity with microscopy and ScanImage (helpful but not required)

### Development Setup
1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/your-username/scanimage-zcontrol.git
   cd scanimage-zcontrol
   ```
3. Add the upstream repository as a remote:
   ```bash
   git remote add upstream https://github.com/guitarbeat/scanimage-zcontrol.git
   ```
4. Set up your MATLAB environment:
   ```matlab
   addpath(genpath('src'))
   ```

## Development Guidelines

### Code Style and Conventions

#### MATLAB Conventions
- **File Names**: Use PascalCase for class files (e.g., `FoilviewController.m`)
- **Function Names**: Use camelCase for functions and methods
- **Variable Names**: Use camelCase for variables, descriptive names preferred
- **Constants**: Use UPPER_CASE with underscores

#### Code Structure
- **Line Length**: Keep lines under 100 characters when possible
- **Indentation**: Use 4 spaces (not tabs)
- **Comments**: Use clear, descriptive comments for complex logic
- **Documentation**: Include function headers with parameter descriptions

#### MATLAB-Specific Guidelines
- **Array Syntax**: Prefer modern array syntax over legacy cell arrays
- **Date/Time**: Use `datetime("now")` instead of `now`
- **Preallocation**: Preallocate arrays in loops to avoid dynamic growth
- **Constructor Calls**: Call constructors directly, avoid `app.Property(args)` for undefined properties

### Architecture Principles

#### Layered Architecture
Follow the established layered architecture:
```
UI Layer (Views) → Controllers → Services → Managers → Hardware
```

#### Dependency Guidelines
- UI components should not directly access hardware
- Services should not contain UI-specific code
- Use dependency injection where possible
- Avoid circular dependencies

#### Event System
- Use the centralized event system for loose coupling
- Document publisher/subscriber relationships
- Avoid circular event dependencies

### Testing

#### Unit Tests
- Write unit tests for new functionality
- Test edge cases and error conditions
- Use descriptive test names that explain the scenario
- Mock dependencies where appropriate

#### Integration Tests
- Test component interactions
- Validate UI component behavior
- Test hardware interface abstractions

#### Manual Testing
- Test UI changes manually
- Verify hardware integration when possible
- Check for timer leaks after application close (`timerfindall()`)

### Pull Request Process

#### Before Submitting
1. **Update from upstream**:
   ```bash
   git fetch upstream
   git checkout main
   git merge upstream/main
   ```

2. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes**:
   - Follow coding conventions
   - Add tests for new functionality
   - Update documentation as needed

4. **Test your changes**:
   - Run existing tests
   - Test manually if UI changes are involved
   - Check for resource leaks

5. **Commit your changes**:
   ```bash
   git add .
   git commit -m "Add descriptive commit message"
   ```

#### Pull Request Guidelines
- **Title**: Use a clear, descriptive title
- **Description**: Explain what changes were made and why
- **Reference Issues**: Link to related issues if applicable
- **Screenshots**: Include screenshots for UI changes
- **Testing**: Describe how changes were tested

#### Pull Request Template
```markdown
## Description
Brief description of changes made.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests added/updated
- [ ] Manual testing completed
- [ ] No timer leaks confirmed

## Screenshots (if applicable)
Include screenshots for UI changes.

## Checklist
- [ ] Code follows project conventions
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] Tests added/updated
```

### Issue Reporting

#### Bug Reports
When reporting bugs, please include:
- MATLAB version
- Operating system
- Steps to reproduce
- Expected vs actual behavior
- Error messages (if any)
- Screenshots (if applicable)

#### Feature Requests
For feature requests, please include:
- Clear description of the feature
- Use case or motivation
- Proposed implementation approach (if applicable)
- Any alternatives considered

## Development Priorities

Current development focus areas (see [todo.md](todo.md) for details):

### High Priority
- Architecture refactoring for modularity
- Unit test coverage improvement
- Configuration-driven UI system
- Resource management and cleanup

### Medium Priority
- Performance optimizations
- Enhanced error handling
- Documentation improvements
- Development tooling enhancements

### Low Priority
- Advanced UI features
- Additional hardware support
- Metrics and monitoring

## Code Review Process

### Review Criteria
- **Functionality**: Does the code work as intended?
- **Architecture**: Does it follow established patterns?
- **Testing**: Are appropriate tests included?
- **Documentation**: Is the code well-documented?
- **Performance**: Are there any performance concerns?

### Review Timeline
- Initial review within 2-3 business days
- Follow-up reviews within 1-2 business days
- Maintainer approval required for merge

## Release Process

### Versioning
We follow semantic versioning (MAJOR.MINOR.PATCH):
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Release Checklist
- [ ] All tests passing
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Version number updated
- [ ] Release notes prepared

## Getting Help

### Resources
- **Documentation**: See [ARCHITECTURE.md](ARCHITECTURE.md) and [LESSONS_LEARNED.mdc](LESSONS_LEARNED.mdc)
- **Issues**: Check existing issues for similar problems
- **Discussions**: Use GitHub Discussions for questions and ideas

### Contact
- Create an issue for bugs or feature requests
- Use GitHub Discussions for general questions
- Tag maintainers in issues if urgent

## Recognition

Contributors are recognized in:
- Project README.md
- Release notes
- Git commit history

Thank you for contributing to the Foilview project!