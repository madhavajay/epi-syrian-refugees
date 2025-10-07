# Analysis Patches

This directory contains patches for the original analysis scripts to ensure compatibility with the current environment and data.

## Patches

### nmds_fix.patch

**Purpose**: Fix NMDS (Non-Metric Multidimensional Scaling) analysis in Stage 1

**Issue**: Original code fails when sample size is small (< 5 samples) because it uses hardcoded `k=4` dimensions

**Solution**:
1. Adaptive k based on sample size: `k = min(4, max(2, n_samples - 1))`
2. Proper data type conversion for df6 matrix
3. Skip analysis entirely if n_samples < 3
4. Preserve row names through transformations

**Applies to**: `script/igp_quality_control_20230222.Rmd`

## Usage

After extracting fresh R markdown files from authors' original sources:

```bash
./patches/apply_patches.sh
```

Or manually:

```bash
patch -p1 < patches/nmds_fix.patch
```

To check if patch is already applied:

```bash
patch -p1 --dry-run < patches/nmds_fix.patch
```

To reverse a patch:

```bash
patch -p1 -R < patches/nmds_fix.patch
```

## Adding New Patches

1. Make changes to the file
2. Create unified diff:
   ```bash
   diff -u original_file modified_file > patches/new_patch.patch
   ```
3. Update `apply_patches.sh` to include new patch
4. Document in this README
