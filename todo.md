# Foilview TODO

## Architecture Refactors
- [ ] Separate business logic from UI in controllers; move UI state to `UIController`/`UIOrchestrator`
- [ ] Remove UI dependencies from services to restore clean layering
- [ ] Introduce dependency injection/factory pattern to avoid direct instantiation and hard-coded class references
- [ ] Define clear interface contracts and naming guidance for `Services` vs `Managers`; eliminate overlap
- [ ] Consolidate services
  - [ ] System Services: merge `ErrorHandlerService`, `LoggingService`, `ApplicationInitializer`
  - [ ] Hardware Services: merge `StageControlService`, `ScanControlService`, `CalibrationService`
  - [ ] Analysis Services: merge `MetricCalculationService`, `MetricsPlotService`

Source: `ARCHITECTURE.md` → Current Architecture Issues, Future Architecture Considerations

## Event System
- [ ] Standardize on a single event mechanism across the app
- [ ] Design and implement a centralized `EventBus` for loose coupling
- [ ] Audit and remove circular event dependencies; document publisher/subscriber relationships

Source: `ARCHITECTURE.md` → Unified Event System

## Configuration-Driven Architecture
- [ ] Expand/replace hard-coded UI layouts with JSON/YAML; extend `src/config/ui_components.json`
- [x] Add schema validation for UI config (e.g., required fields, type checking)
  - Implemented in `src/ui/ComponentFactory.m` (`validateConfigSchema`)
- [ ] Implement plugin architecture for hardware components; runtime discovery/selection
- [ ] Support runtime configuration toggles without code changes

Source: `ARCHITECTURE.md` → Configuration-Driven Architecture

## Testing & Quality Engineering
- [ ] Unit tests for `ComponentFactory` JSON handling (cell vs struct arrays)
- [ ] Isolation/integration tests for `UiBuilder.build()` pipeline
- [ ] Introduce dependency inversion to enable mocking in unit tests
- [ ] Create a MATLAB style/conventions guide (array syntax, line continuation, datetime usage, preallocation, constructor calls)

Source: `LESSONS_LEARNED.mdc` → JSON handling, Method visibility, Testing strategy, Array syntax, Date/Time, Loop performance, Object instantiation

## Code Quality Audits (Safe Refactors)
- [x] Replace usage of `now` with `datetime("now")` across codebase
  - Updated: `src/services/UserNotificationService.m`, `src/services/LoggingService.m`, `src/services/ApplicationInitializer.m`, `src/services/ErrorHandlerService.m`, `src/views/MJC3View.m`
- [ ] Preallocate arrays in loops; remove dynamic growth patterns
- [ ] Ensure constructors are called directly (avoid `app.Property(args)` for undefined properties)
- [ ] Normalize controller lifecycle API: prefer `enable()`/`disable()`; remove mismatched `stop()` calls
- [x] Add startup path hygiene: ensure `src/hardware/` (and others) added to MATLAB path centrally
  - Added `setupApplicationPaths` in `src/services/ApplicationInitializer.m`

Source: `LESSONS_LEARNED.mdc` → Date/Time, Loop performance, Object instantiation, Method signature mismatch, Path management

## Resource Management & Cleanup
- [ ] Implement comprehensive cleanup chain:
  - [ ] Stop/delete all timers
  - [ ] Close MEX connections
  - [ ] Safe UI figure deletion with recursion prevention
  - [ ] Reset controller/component state (`IsEnabled`, `IsConnected`, etc.)
- [ ] Add regression checks to ensure zero timer leaks after app close (`timerfindall()`)

Source: `LESSONS_LEARNED.mdc` → Application Cleanup and Resource Management

## Documentation
- [ ] Document MATLAB version compatibility and MEX build/test commands
- [ ] Update `ARCHITECTURE.md` with DI/EventBus decisions and service consolidation outcomes

Source: `LESSONS_LEARNED.mdc` → MATLAB Version Compatibility; `ARCHITECTURE.md` → Future Architecture Considerations

## UX Improvements
- [ ] Apply basic visual design: spacing, alignment, hierarchy, grouping in `MJC3View`, `StageView`, and related views

Source: `LESSONS_LEARNED.mdc` → UI Design Fundamentals

## Success Metrics & Tracking
- [ ] Define measurable outcomes for each refactor (e.g., lines reduced per file, dependency graph simplification, unit test coverage %, latency/throughput targets)
- [ ] Track completion status and link PRs/issues for each checklist item

## Repository Management & GitHub Best Practices
- [ ] Create comprehensive README.md with project description, installation, and usage instructions
- [ ] Add project badges (build status, license, MATLAB version compatibility)
- [ ] Set up GitHub issue templates for bug reports and feature requests
- [ ] Create pull request template with checklist for contributors
- [ ] Add CONTRIBUTING.md with development guidelines and coding standards
- [ ] Create CHANGELOG.md to track version history and notable changes
- [ ] Set up GitHub Discussions for community Q&A and announcements
- [ ] Add repository topics/tags for better discoverability (matlab, microscopy, scanimage, hardware-control)

Source: Repository exploration - missing standard GitHub repository files

## Continuous Integration & Deployment
- [ ] Set up GitHub Actions for automated MATLAB testing
- [ ] Create workflow for MEX compilation and testing across MATLAB versions
- [ ] Add automated code quality checks (MATLAB Code Analyzer)
- [ ] Implement automated documentation generation
- [ ] Set up dependency vulnerability scanning
- [ ] Create release automation workflow with semantic versioning
- [ ] Add automated backup of development tools and configurations

Source: Repository exploration - no CI/CD workflows found

## Project Maintenance & Community
- [ ] Create GitHub project boards for task tracking and milestone management
- [ ] Set up automated issue labeling and triage
- [ ] Add security policy (SECURITY.md) for vulnerability reporting
- [ ] Create user documentation wiki or GitHub Pages site
- [ ] Set up automated dependency updates (dependabot equivalent for MATLAB)
- [ ] Add code of conduct for community interactions
- [ ] Create issue/PR auto-close policies for stale items

Source: Repository exploration - minimal issue/PR activity, community features missing

## Development Environment & Tooling
- [ ] Enhance dev-tools with additional MATLAB static analysis
- [ ] Add pre-commit hooks for code formatting and basic checks
- [ ] Create Docker/container setup for consistent development environment
- [ ] Add MATLAB package (.mltbx) build automation
- [ ] Implement automated MEX compilation testing across platforms
- [ ] Create development setup script for new contributors
- [ ] Add performance benchmarking and regression testing tools

Source: `dev-tools/` directory analysis and MATLAB development best practices

## Hardware Integration & Testing
- [ ] Address foilview application initialization issues from .kiro/specs requirements
- [ ] Implement robust ScanImage connection handling with fallback modes
- [ ] Add comprehensive hardware abstraction layer testing
- [ ] Create hardware simulation framework for development without physical devices
- [ ] Implement hardware compatibility matrix and testing
- [ ] Add automatic hardware detection and configuration
- [ ] Create hardware troubleshooting and diagnostic tools

Source: `.kiro/specs/foilview-fixes/requirements.md` and hardware integration challenges

## Performance & Reliability
- [ ] Implement comprehensive application lifecycle management
- [ ] Add memory leak detection and prevention
- [ ] Create performance monitoring and metrics collection
- [ ] Implement automatic crash recovery and state persistence
- [ ] Add comprehensive error tracking and reporting
- [ ] Create system resource monitoring (timers, handles, connections)
- [ ] Implement graceful degradation for hardware failures

Source: `LESSONS_LEARNED.mdc` - resource management and cleanup issues

## Continuous Integration & Deployment
- [ ] Set up GitHub Actions for automated MATLAB testing
- [ ] Create workflow for MEX compilation and testing across MATLAB versions
- [ ] Add automated code quality checks (MATLAB Code Analyzer)
- [ ] Implement automated documentation generation
- [ ] Set up dependency vulnerability scanning
- [ ] Create release automation workflow with semantic versioning
- [ ] Add automated backup of development tools and configurations

Source: Repository exploration - no CI/CD workflows found

## Project Maintenance & Community
- [ ] Create GitHub project boards for task tracking and milestone management
- [ ] Set up automated issue labeling and triage
- [ ] Add security policy (SECURITY.md) for vulnerability reporting
- [ ] Create user documentation wiki or GitHub Pages site
- [ ] Set up automated dependency updates (dependabot equivalent for MATLAB)
- [ ] Add code of conduct for community interactions
- [ ] Create issue/PR auto-close policies for stale items

Source: Repository exploration - minimal issue/PR activity, community features missing

## Development Environment & Tooling
- [ ] Enhance dev-tools with additional MATLAB static analysis
- [ ] Add pre-commit hooks for code formatting and basic checks
- [ ] Create Docker/container setup for consistent development environment
- [ ] Add MATLAB package (.mltbx) build automation
- [ ] Implement automated MEX compilation testing across platforms
- [ ] Create development setup script for new contributors
- [ ] Add performance benchmarking and regression testing tools

Source: `dev-tools/` directory analysis and MATLAB development best practices

## Hardware Integration & Testing
- [ ] Address foilview application initialization issues from .kiro/specs requirements
- [ ] Implement robust ScanImage connection handling with fallback modes
- [ ] Add comprehensive hardware abstraction layer testing
- [ ] Create hardware simulation framework for development without physical devices
- [ ] Implement hardware compatibility matrix and testing
- [ ] Add automatic hardware detection and configuration
- [ ] Create hardware troubleshooting and diagnostic tools

Source: `.kiro/specs/foilview-fixes/requirements.md` and hardware integration challenges

## Performance & Reliability
- [ ] Implement comprehensive application lifecycle management
- [ ] Add memory leak detection and prevention
- [ ] Create performance monitoring and metrics collection
- [ ] Implement automatic crash recovery and state persistence
- [ ] Add comprehensive error tracking and reporting
- [ ] Create system resource monitoring (timers, handles, connections)
- [ ] Implement graceful degradation for hardware failures

Source: `LESSONS_LEARNED.mdc` - resource management and cleanup issues

---

Notes
- Keep edits incremental; prefer small PRs focused on one topic (e.g., EventBus, DI introduction, or a single service merge)
- Ensure all refactors preserve behavior; add tests first when practical
- Update this file as tasks are completed; cross-reference with PRs/issues
- New sections added based on GitHub repository exploration and standard open-source practices
- Prioritize README.md creation and basic repository setup before advanced features
