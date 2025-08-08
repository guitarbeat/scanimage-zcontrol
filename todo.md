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

---

Notes
- Keep edits incremental; prefer small PRs focused on one topic (e.g., EventBus, DI introduction, or a single service merge)
- Ensure all refactors preserve behavior; add tests first when practical
- Update this file as tasks are completed; cross-reference with PRs/issues
