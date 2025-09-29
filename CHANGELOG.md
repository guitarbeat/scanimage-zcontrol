# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive README.md with project description, installation, and usage instructions
- CONTRIBUTING.md with development guidelines and coding standards
- GitHub issue templates for bug reports and feature requests
- Pull request template with contributor checklist
- CHANGELOG.md for tracking version history

### Changed
- Cleaned up todo.md by removing duplicate sections

### Fixed
- Removed duplicate sections in todo.md file structure

## Project History

### Key Completed Features (Pre-Changelog)
- [x] Schema validation for UI config in `src/ui/ComponentFactory.m`
- [x] Replaced usage of `now` with `datetime("now")` across codebase
- [x] Added startup path hygiene with `setupApplicationPaths` in `src/services/ApplicationInitializer.m`

### Architecture Achievements
- Layered architecture with UI → Controllers → Services → Managers → Hardware
- Dynamic UI component creation system
- Event coordination and orchestration
- Comprehensive service layer for business logic
- Hardware abstraction for ScanImage integration
- MJC3 joystick integration with calibration
- Real-time focus metrics and plotting
- Bookmark management and metadata logging

### Known Issues
- Timer leak prevention needs improvement
- Circular event dependencies exist in some components
- UI dependencies in services need cleanup
- Resource management cleanup chain needs implementation

---

### Notes on Versioning
- **MAJOR**: Breaking changes to public API or core functionality
- **MINOR**: New features that are backward compatible
- **PATCH**: Bug fixes and minor improvements that are backward compatible

### Changelog Guidelines
- Keep an "Unreleased" section at the top for upcoming changes
- Group changes into: Added, Changed, Deprecated, Removed, Fixed, Security
- Include issue/PR references where applicable
- Date releases in YYYY-MM-DD format
- Use semantic versioning for release numbers