# Dev-Tools Directory

This directory contains diagnostic and analysis tools for the MATLAB project.

## Scripts Overview

### 🧹 analyze_dead_code.m
Comprehensive dead code analysis tool that identifies potentially unused functions in your codebase.

**Features:**
- Detects unused functions with confidence scoring
- Identifies suspicious functions that may be called dynamically
- Protects essential MATLAB functions from false positives
- Provides detailed recommendations for code cleanup

**Usage:**
```matlab
analyze_dead_code()                    % Analyze src/ directory
analyze_dead_code('verbose', true)     % Enable detailed output
analyze_dead_code('path', 'custom/')   % Analyze custom directory
```

**Output:** `dev-tools/output/dead_code_analysis_YYYYMMDD_HHMMSS.txt`

### 🔬 comprehensive_scanimage_diagnostic.m
Advanced diagnostic tool for ScanImage data access and object exploration.

**Features:**
- Verifies ScanImage status and configuration
- Tests multiple pixel data access methods
- Analyzes data quality and focus metrics
- Explores complete object structure
- Provides working integration code

**Usage:**
```matlab
comprehensive_scanimage_diagnostic()                   % Standard diagnostics
comprehensive_scanimage_diagnostic('Verbose', true)    % Detailed output
comprehensive_scanimage_diagnostic('TestFocus', false) % Skip focus metrics
```

**Output:** `dev-tools/output/scanimage_diagnostic_YYYYMMDD_HHMMSS.txt`

### 🚀 run_diagnostics.m
Convenient wrapper to run diagnostic tools with clean output management.

**Usage:**
```matlab
run_diagnostics()                    % Run both tools
run_diagnostics('deadcode')          % Run only dead code analysis
run_diagnostics('scanimage')         % Run only scanimage diagnostic
run_diagnostics('verbose', true)     % Enable verbose output
run_diagnostics('open', true)        % Open output files after running
```

## Output Management

All diagnostic tools now save their results to timestamped files in the `dev-tools/output/` directory instead of cluttering the console. This provides:

- **Clean console output** - Only essential progress information
- **Persistent results** - Reports saved for later reference
- **Organized storage** - All outputs in dedicated folder
- **Timestamped files** - Easy to track when diagnostics were run

## Quick Start

1. **Run all diagnostics:**
   ```matlab
   run_diagnostics('verbose', true, 'open', true)
   ```

2. **View latest results:**
   ```matlab
   % List output files
   dir('dev-tools/output/*.txt')
   
   % Open most recent dead code analysis
   edit('dev-tools/output/dead_code_analysis_*.txt')
   ```

3. **Clean up unused code:**
   - Review the dead code analysis report
   - Verify functions are truly unused
   - Remove functions incrementally with testing

## File Structure

```
dev-tools/
├── analyze_dead_code.m              % Dead code analysis tool
├── comprehensive_scanimage_diagnostic.m  % ScanImage diagnostic tool
├── run_diagnostics.m                % Convenient wrapper script
├── output/                          % Output directory for reports
│   ├── .gitkeep                    % Directory info and usage
│   ├── dead_code_analysis_*.txt    % Dead code analysis reports
│   └── scanimage_diagnostic_*.txt  % ScanImage diagnostic reports
└── README.md                       % This file
```

## Benefits of Clean Output

- **Reduced noise** - Console shows only essential information
- **Better organization** - All reports in one place
- **Historical tracking** - Keep multiple diagnostic runs
- **Easy sharing** - Send specific report files to colleagues
- **Automated workflows** - Scripts can be run in batch without overwhelming output