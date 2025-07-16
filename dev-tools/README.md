# Development Tools

This directory contains diagnostic, testing, and maintenance tools for the foilview application.

## Directory Structure

```
dev-tools/
├── diagnostics/          # Analysis and diagnostic scripts
├── fixes/               # Automated fix scripts
├── testing/             # Test and simulation scripts
├── analysis/            # Code analysis and reports
├── docs/               # Development documentation
├── backup/             # Backup files and legacy code
└── scanimage-context/  # ScanImage-specific configuration
```

## Quick Reference

### Diagnostics
- Run `diagnostics/diagnose_autocontrols_visibility.m` to check UI visibility issues
- Use `diagnostics/diagnose_scanimage_data.m` for ScanImage integration problems
- Check `diagnostics/diagnose_motor_controls.m` for motor control issues

### Fixes
- Apply `fixes/comprehensive_autocontrols_fix.m` for complete auto controls fixes
- Use `fixes/fix_layout_proportions.m` for runtime layout adjustments
- Run `fixes/fix_uibuilder_proportions.m` for permanent source code fixes

### Testing
- Start simulation with `testing/start_foilview_simulation.m`
- Test services with `testing/test_service_integration.m`
- Verify changes with `testing/verify_refactoring.m`

### Analysis
- Review `analysis/dead_code_report.txt` for unused code
- Check `analysis/auto_step_code_map.md` for auto-step functionality mapping

## Usage Workflow

1. **Diagnose** → Run diagnostic scripts to identify issues
2. **Fix** → Apply appropriate fix scripts
3. **Test** → Verify fixes with testing scripts
4. **Analyze** → Review code health and documentation