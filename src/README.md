# Source R Markdown Files

This directory contains versions of the R markdown analysis scripts that are tracked in git.

## Files

### igp_quality_control_20230222.Rmd (Original)

**Source**: `data/22183534/igp_quality_control_20230222.Rmd` (from authors' published data)

**Purpose**: Original Stage 1 QC analysis script as published by the authors

**Status**: Reference copy, not modified

**Usage**: Default when running `./run_stage1.sh` (via symlink in script/)

### igp_quality_control_20230222_test.Rmd (Test Mode)

**Source**: Modified from original for testing with small sample sizes

**Purpose**: Low-sample variant for quick testing (4 samples instead of 160)

**Modifications**:
- Optimized for small sample sizes
- Reduced runtime for development/testing

**Usage**: Automatically selected with `./run_stage1.sh --test`

### igp_quality_control_20230222_fixed.Rmd (Fixed)

**Source**: Modified from original with environment compatibility fixes

**Purpose**: Production version with fixes for current environment

**Modifications**:
1. **NMDS Analysis Fix** (lines 225-288):
   - Adaptive k parameter based on sample size: `k = min(4, max(2, n_samples - 1))`
   - Proper numeric matrix conversion for df6
   - Skip analysis if n_samples < 3
   - Preserve row names through transformations

**Usage**: Explicitly select with `./run_stage1.sh --fixed`

**See also**: `patches/nmds_fix.patch` for details of changes

## Workflow

1. **Development/Testing**: Use `--test` flag for quick iterations
   ```bash
   ./run_stage1.sh --test
   ```

2. **Fixed Version**: Use `--fixed` flag for production with fixes
   ```bash
   ./run_stage1.sh --fixed
   ```

3. **Original**: Use without flags (runs via symlink from data/)
   ```bash
   ./run_stage1.sh
   ```

## Directory Structure

```
src/                              # Tracked in git
├── igp_quality_control_20230222.Rmd         # Original (reference)
├── igp_quality_control_20230222_test.Rmd    # Test mode
└── igp_quality_control_20230222_fixed.Rmd   # Fixed version

script/                           # NOT tracked in git (in .gitignore)
└── igp_quality_control_20230222.Rmd -> ../data/22183534/...  # Symlink to original

data/22183534/                    # Extracted from archives
└── igp_quality_control_20230222.Rmd         # Published by authors
```

## Making Changes

When modifying analysis scripts:

1. Make changes in `src/igp_quality_control_20230222_fixed.Rmd`
2. Test with: `./run_stage1.sh --fixed`
3. Commit changes to git
4. Original and test versions remain unchanged for reference

## Patch Files

For reproducibility and documentation, major fixes are also documented as patch files in `patches/`:

- `patches/nmds_fix.patch` - NMDS analysis fix for small sample sizes
- `patches/apply_patches.sh` - Script to apply patches (if needed)

See `patches/README.md` for more details.
