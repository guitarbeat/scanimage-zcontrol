# Migration Checklist: Modularizing `src/`

This document tracks the step-by-step migration of the `src/` folder to a modular, maintainable structure.

---

## 1. Preparation & Planning
- [ ] **Review dependency report**: Identify the most-coupled files (already done)
- [ ] **Create a migration branch**: e.g., `refactor/modularize-src`
- [ ] **Write a high-level README** for `src/` describing the new folder/module structure and migration goals

---

## 2. Create New Folder Structure
- [ ] Add new folders:
  - [ ] `services/` (for business logic, no GUI)
  - [ ] `models/` (for data structures, if needed)
- [ ] In `utils/`, plan submodules: e.g., `ConfigUtils.m`, `FilePathUtils.m`, `NumericUtils.m`
- [ ] In `services/`, add a `README.md` describing service conventions

---

## 3. Extract and Refactor Services
### 3.1. Plotting Logic
- [x] Create `services/MetricsPlotService.m` (COMPLETED)
- [x] Move all plotting logic from `PlotManager.m` and `FoilviewController.m` into `MetricsPlotService.m` (COMPLETED)
- [x] Refactor `PlotManager.m` to call `MetricsPlotService` for all plot operations (COMPLETED)
- [ ] Update all usages in `foilview.m` and elsewhere to use the new service

### 3.2. Scan Control Logic
- [x] Create `services/ScanControlService.m` (COMPLETED)
- [ ] Move scan start/stop, parameter validation, and related logic from `FoilviewController.m` and `ScanImageManager.m` into `ScanControlService.m`
- [ ] Refactor `FoilviewController.m` to delegate scan operations to the service

### 3.3. Metadata Service
- [x] Create `services/MetadataService.m` (COMPLETED)
- [ ] Move metadata logging logic from `foilview.m` into `MetadataService.m`
- [ ] Update BookmarkManager to use MetadataService

---

## 4. Shrink and Split Utils
- [x] Split `FoilviewUtils.m` into focused modules:
  - [x] `ConfigUtils.m` (COMPLETED)
  - [x] `FilePathUtils.m` (COMPLETED)
  - [x] `NumericUtils.m` (COMPLETED)
- [ ] Move each function to the appropriate new file
- [ ] Update all imports/usages across the codebase

## 4.1. New Controllers
- [x] Create `controllers/UIController.m` (COMPLETED)
- [ ] Move UI update logic from `foilview.m` to `UIController.m`
- [ ] Refactor `FoilviewController.m` to focus on business logic only

---

## 5. Enforce Clear Dependencies
- [ ] Update code so:
  - Controllers only depend on managers + views
  - Views only depend on components + utils
  - Managers only depend on services + utils
  - Services only depend on core MATLAB + models
- [ ] Remove any “upward” or cross-layer dependencies

---

## 6. Incremental Migration & Testing
- [ ] After each major move/refactor, run the app and existing tests
- [ ] Update or add unit tests for each new service and utility
- [ ] Refactor in small, testable increments (commit after each)

---

## 7. Automate Dependency Checks
- [ ] Add a CI step (or a pre-commit hook) to check for new circular dependencies
- [ ] Fail the build if new cycles are introduced

---

## 8. Documentation
- [ ] Add/Update `README.md` files in each major folder:
  - Describe the folder’s purpose, public API, and usage examples
- [ ] Document each service’s interface

---

## 9. Final Cleanup
- [ ] Remove any obsolete files or dead code
- [ ] Update all references to moved/renamed files
- [ ] Run a full regression test suite
- [ ] Update the main project `README.md` to reflect the new structure 