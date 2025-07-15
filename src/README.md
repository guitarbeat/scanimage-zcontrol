# src/

This folder contains the main application code for the ScanImage Z-Control project.

## Folder Structure (Post-Migration)

- `app/` — Main entry point and application bootstrap (e.g., foilview.m)
- `controllers/` — Application controllers (UI event wiring, coordination)
- `managers/` — Stateful managers for bookmarks, ScanImage, etc.
- `services/` — Standalone business-logic modules (no GUI code)
- `views/` — UI windows and subviews
  - `components/` — Reusable UI components (e.g., PlotManager, UiBuilder)
- `utils/` — Focused utility modules (e.g., ConfigUtils, FilePathUtils, NumericUtils)
- `models/` — (Optional) Data structures and domain models

## Migration Goals

- Reduce cross-dependencies and improve modularity
- Make each layer (controllers, managers, services, views, utils) focused and testable
- Enable isolated unit testing of business logic
- Document clear public APIs for each module
- Make onboarding and maintenance easier for new contributors

See `MIGRATION_CHECKLIST.md` for step-by-step progress. 