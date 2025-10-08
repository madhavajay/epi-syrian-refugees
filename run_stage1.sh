#!/bin/bash

set -e  # Exit on error

# Parse command line arguments
TEST_MODE=false
FIXED_MODE=false
DOCKER_MODE=false
NO_DOCKER_FLAG=false
CORES=""
STAGE=""
PASSTHRU_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --test)
            TEST_MODE=true
            PASSTHRU_ARGS+=(--test)
            shift
            ;;
        --fixed)
            FIXED_MODE=true
            shift
            ;;
        --docker)
            DOCKER_MODE=true
            shift
            ;;
        --no-docker)
            NO_DOCKER_FLAG=true
            shift
            ;;
        --cores)
            CORES="$2"
            shift 2
            ;;
        --stage)
            STAGE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--test] [--fixed] [--docker] [--cores N] [--stage N]"
            echo ""
            echo "Stages:"
            echo "  1 = Setup & Initial QC (quick)"
            echo "  2 = Read IDATs & Correlations (8-12 hours) [default]"
            echo "  3 = Replicate Analysis"
            echo "  4 = Full QC"
            echo "  5 = Complete Analysis"
            exit 1
            ;;
    esac
done

if [ "$DOCKER_MODE" = true ] && [ "$NO_DOCKER_FLAG" = false ]; then
    docker run --rm -v "$(pwd)":/workspace -w /workspace -e IGP_CORES="${IGP_CORES:-}" -e IGP_TEST_MODE="$([ "$TEST_MODE" = true ] && echo 1 || echo 0)" \
        epi-syrian-refugees ./link_data.sh
    docker run --rm -v "$(pwd)":/workspace -w /workspace -e IGP_CORES="${IGP_CORES:-}" -e IGP_TEST_MODE="$([ "$TEST_MODE" = true ] && echo 1 || echo 0)" \
        epi-syrian-refugees Rscript -e "setwd('/workspace'); system('./run_stage1_rscript.R ${PASSTHRU_ARGS[*]}')"
    exit $?
fi

if [ "$TEST_MODE" = true ]; then
    echo "========================================="
    echo "Stage 1: Quality Control (TEST MODE)"
    echo "Epigenetic Violence Analysis"
    echo "========================================="
    echo ""
    echo "⚠ Running in test mode with 4 samples only"
    echo "  For full analysis, run without --test flag"
    echo ""
else
    echo "========================================="
    echo "Stage 1: Quality Control & Data Processing"
    echo "Epigenetic Violence Analysis"
    echo "========================================="
    echo ""
fi

# Check prerequisites
echo "Checking prerequisites..."
echo ""

# Check if environment exists
ENV_DIR="./envs/epigenetic-violence-analysis"
if [ ! -d "$ENV_DIR" ]; then
    echo "✗ Environment not found: $ENV_DIR"
    echo "  Run ./setup_environment.sh first"
    exit 1
fi

ENV_ABS_PATH=$(cd "$ENV_DIR" && pwd)
RMD_PATH_BASE="script/igp_quality_control_20230222.Rmd"
RMD_PATH_TEST="src/igp_quality_control_20230222_test.Rmd"
RMD_PATH_FIXED="src/igp_quality_control_20230222_fixed.Rmd"

# Select appropriate R markdown file based on flags
if [ "$TEST_MODE" = true ]; then
    RMD_PATH="$RMD_PATH_TEST"
elif [ "$FIXED_MODE" = true ]; then
    RMD_PATH="$RMD_PATH_FIXED"
else
    RMD_PATH="$RMD_PATH_BASE"
fi

# Set number of cores (priority: --cores flag > IGP_CORES env var > default 8)
if [ -n "$CORES" ]; then
    export IGP_CORES="$CORES"
else
    export IGP_CORES=${IGP_CORES:-8}
fi

# Set analysis stage (priority: --stage flag > IGP_STAGE env var > default 2)
if [ -n "$STAGE" ]; then
    export IGP_STAGE="$STAGE"
else
    export IGP_STAGE=${IGP_STAGE:-2}
fi

export IGP_TEST_MODE=0
export DYLD_FALLBACK_LIBRARY_PATH="$(pwd)/libs:${DYLD_FALLBACK_LIBRARY_PATH:-}"
IDAT_DOWNLOAD_DIR="$(pwd)/downloads/idat"
echo "✓ Environment found"

# Clean up conflicting CSV files in data/ directory
# minfi::read.metharray.sheet() reads ALL CSV files, so we need to ensure
# only the correct SampleSheet exists based on test mode
if [ "$TEST_MODE" = true ]; then
    # Test mode: Keep test file, backup production file
    if [ -f "data/cMulligan_SampleSheet160.csv" ]; then
        mv -f data/cMulligan_SampleSheet160.csv data/cMulligan_SampleSheet160.csv.bak 2>/dev/null || true
    fi
    if [ -f "data/cMulligan_SampleSheet_test.csv.bak" ]; then
        mv -f data/cMulligan_SampleSheet_test.csv.bak data/cMulligan_SampleSheet_test.csv 2>/dev/null || true
    fi
else
    # Production mode: Keep production file, backup test file
    if [ -f "data/cMulligan_SampleSheet_test.csv" ]; then
        mv -f data/cMulligan_SampleSheet_test.csv data/cMulligan_SampleSheet_test.csv.bak 2>/dev/null || true
    fi
    if [ -f "data/cMulligan_SampleSheet160.csv.bak" ]; then
        mv -f data/cMulligan_SampleSheet160.csv.bak data/cMulligan_SampleSheet160.csv 2>/dev/null || true
    fi
fi

# Check if directories are set up
if [ ! -d "supp_data" ] || [ ! -d "output" ] || [ ! -d "script" ]; then
    echo "✗ Directory structure not set up"
    echo "  Run ./extract.sh followed by ./link_data.sh"
    exit 1
fi
echo "✓ Directory structure set up"

# Check if analysis script exists
if [ ! -f "$RMD_PATH_BASE" ]; then
    echo "✗ Analysis script not found: $RMD_PATH_BASE"
    if [ "$NO_DOCKER_FLAG" = false ]; then
        echo "  Attempting to refresh symlinks via ./link_data.sh"
        if ./link_data.sh; then
            if [ ! -f "$RMD_PATH_BASE" ]; then
                echo "  ✗ Script still missing after link refresh"
                exit 1
            fi
        else
            echo "  ✗ Failed to refresh symlinks; please run ./link_data.sh manually"
            exit 1
        fi
    else
        echo "  Run ./link_data.sh to create symlinks"
        exit 1
    fi
fi
echo "✓ Analysis script found"

# Ensure clustering chunk handles small sample sizes
python3 - <<'PY'
from pathlib import Path

paths = [
    'script/igp_quality_control_20230222.Rmd',
    'src/igp_quality_control_20230222_test.Rmd',
    'src/igp_quality_control_20230222_fixed.Rmd',
]

cluster_old = """plot(fit) # display dendogram\nrect.hclust(fit,k=54)\n\ngroups <- cutree(fit, k=54)\n\ngroups <- as.data.frame(groups)\n\ngroups <- cbind(groups, metadata)\n"""

cluster_new = """plot(fit) # display dendogram\nsample_count <- length(fit$order)\n\nif (is.na(sample_count) || sample_count < 2) {\n    warning(\"Not enough samples for clustering rectangles; skipping cutree step for this dataset\")\n    groups <- data.frame()\n} else {\n    k_target <- min(54, max(2, sample_count - 1))\n    rect.hclust(fit, k = k_target)\n\n    groups <- cutree(fit, k = k_target)\n\n    groups <- as.data.frame(groups)\n\n    groups <- cbind(groups, metadata)\n}\n"""

sheet_old = 'targets <- read.metharray.sheet(here("data"))'
sheet_new = r'targets <- read.metharray.sheet(here("data"), pattern = "cMulligan_SampleSheet160\\.csv$")'

for path_str in paths:
    path = Path(path_str)
    if not path.exists():
        continue
    text = path.read_text()
    updated = False
    if cluster_old in text:
        text = text.replace(cluster_old, cluster_new, 1)
        updated = True
    if sheet_old in text:
        text = text.replace(sheet_old, sheet_new)
        updated = True
    if updated:
        path.write_text(text)
PY

# Ensure IDAT symlinks are refreshed from downloads when available
if [ -d "$IDAT_DOWNLOAD_DIR" ]; then
    mkdir -p data/idat
    find data/idat -maxdepth 1 -type l -exec rm -f {} \;
    find data -maxdepth 1 -type l \( -name "*.idat.gz" -o -name "*.idat" \) -exec rm -f {} \;

    if compgen -G "$IDAT_DOWNLOAD_DIR/*.idat.gz" > /dev/null; then
        echo "Linking IDAT files from downloads/..."
        while IFS= read -r idat_path; do
            base_name=$(basename "$idat_path")
            ln -sf "$IDAT_DOWNLOAD_DIR/$base_name" "data/idat/$base_name"

            trimmed_name=$(echo "$base_name" | sed 's/^GSM[0-9]*_//')
            if [[ "$trimmed_name" != "$base_name" ]]; then
                # Only create .gz symlink - R packages handle .gz directly
                ln -sf "$IDAT_DOWNLOAD_DIR/$base_name" "data/${trimmed_name}"
            fi
        done < <(find "$IDAT_DOWNLOAD_DIR" -maxdepth 1 -type f -name "*.idat.gz")
        echo "✓ IDAT symlinks refreshed"
    fi
fi

# Check IDAT files
idat_count=$(find data -name "*.idat.gz" 2>/dev/null | wc -l | tr -d ' ')

if [ "$TEST_MODE" = true ]; then
    # In test mode, we only need 8 IDAT files (4 samples × 2 channels)
    if [ "$idat_count" -lt 8 ]; then
        echo "✗ Not enough IDAT files for test mode"
        echo "  Need at least 8 files (4 samples × 2 channels), found $idat_count"
        echo "  Run ./download.sh to download IDAT files"
        exit 1
    else
        echo "✓ Found $idat_count IDAT files (sufficient for test)"
    fi
else
    # Full mode needs all 320 files
    if [ "$idat_count" -lt 320 ]; then
        echo "⚠ Warning: Only $idat_count/320 IDAT files found"
        echo "  Expected 320 files (160 samples × 2 channels)"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborted. Run ./download.sh to download IDAT files"
            exit 1
        fi
    else
        echo "✓ Found $idat_count IDAT files"
    fi
fi

# Check critical input files
echo ""
echo "Checking critical input files..."

# Repair sample sheet symlink if it accidentally points to data/data/...
SAMPLE_SHEET="data/cMulligan_SampleSheet160.csv"
SAMPLE_SHEET_SRC="data/22183534/cMulligan_SampleSheet160.csv"
if [ ! -f "$SAMPLE_SHEET" ] && [ -L "$SAMPLE_SHEET" ]; then
    rm -f "$SAMPLE_SHEET"
fi
if [ ! -f "$SAMPLE_SHEET" ] && [ -f "$SAMPLE_SHEET_SRC" ]; then
    echo "  ↻ Restoring sample sheet from extracted data/..."
    cp "$SAMPLE_SHEET_SRC" "$SAMPLE_SHEET"
fi

critical_files=(
    "data/cMulligan_SampleSheet160.csv"
    "supp_data/cMulligan_SampleManifest160.csv"
    "supp_data/IGP_SwabType.csv"
    "supp_data/igp_ages.csv"
    "supp_data/datMiniAnnotation3.csv"
    "output/igp_horvath_betas_20211104.csv"
    "output/igp_horvath_betas_20211104.output.csv"
)

missing_files=0
for file in "${critical_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "  ✗ Missing: $file"
        missing_files=$((missing_files + 1))
    fi
done

if [ $missing_files -gt 0 ]; then
    echo ""
    echo "✗ $missing_files critical files missing"
    echo "  Run ./link_data.sh to set up symlinks"
    exit 1
fi
echo "✓ All critical files present"

echo ""
echo "========================================="
echo "Starting Stage 1 QC Analysis"
echo "========================================="
echo ""

# Clean up intermediate RDS files from previous failed runs
echo "Cleaning intermediate cache files..."
intermediate_files=(
    "output/raw_betas.rds"
    "output/preprocessed_betas.rds"
    "output/noob_betas.rds"
)

removed_count=0
for file in "${intermediate_files[@]}"; do
    if [ -f "$file" ]; then
        # Check if file is very small (likely corrupted from failed run)
        size=$(wc -c < "$file" 2>/dev/null || echo "0")
        if [ "$size" -lt 1000 ]; then
            rm -f "$file"
            echo "  ✓ Removed corrupted cache: $file (${size} bytes)"
            removed_count=$((removed_count + 1))
        fi
    fi
done

if [ $removed_count -eq 0 ]; then
    echo "  ✓ No corrupted cache files found"
fi
echo ""

# Set up test mode if requested
if [ "$TEST_MODE" = true ]; then
    echo "Test Mode Configuration:"
    echo "  - Creating test sample sheet (4 samples)..."
    export IGP_TEST_MODE=1

    # Create test sample sheet
    ./create_test_samplesheet.sh

    # Backup original and use test version
    if [ ! -f "data/cMulligan_SampleSheet160.csv.backup" ]; then
        cp data/cMulligan_SampleSheet160.csv data/cMulligan_SampleSheet160.csv.backup
    fi
    cp data/cMulligan_SampleSheet_test.csv data/cMulligan_SampleSheet160.csv

    echo "  - Using low-sample variant of QC notebook"
    if [ ! -f "$RMD_PATH_TEST" ]; then
        echo "✗ Test R Markdown not found: $RMD_PATH_TEST"
        echo "  Re-run link_data.sh to restore extracted scripts"
        exit 1
    fi
    RMD_PATH="$RMD_PATH_TEST"

    echo ""
    echo "Estimated runtime: 30-60 minutes"
    echo "RAM required: 16-32 GB"
    echo "Output: script/igp_quality_control_20230222.html"
    echo ""
else
    echo "Estimated runtime: 8-12 hours"
    echo "RAM required: 128 GB"
    echo "Output: script/igp_quality_control_20230222.html"
    echo ""
fi

# Validate fixed version if requested
if [ "$FIXED_MODE" = true ]; then
    echo "⚙ Using fixed version of QC script"
    if [ ! -f "$RMD_PATH" ]; then
        echo "✗ Fixed R Markdown not found: $RMD_PATH"
        echo "  The fixed version should be tracked in git"
        exit 1
    fi
    echo ""
fi

# Prepare Rscript runner
ARCH=$(uname -m)
RSCRIPT_BIN="$ENV_ABS_PATH/bin/Rscript"
if [ ! -x "$RSCRIPT_BIN" ]; then
    echo "✗ Rscript binary not found in $RSCRIPT_BIN"
    echo "  Ensure ./setup_environment.sh completed successfully"
    exit 1
fi

export PATH="$ENV_ABS_PATH/bin:$PATH"

RSCRIPT_CMD=("$RSCRIPT_BIN")
if [[ "$ARCH" == "arm64" ]]; then
    export CONDA_SUBDIR=osx-64
    RSCRIPT_CMD=(arch -x86_64 "$RSCRIPT_BIN")
    echo "Running on Apple Silicon - using Rosetta 2 for x86_64 compatibility"
    echo ""
fi

# Configure parallel processing
NUM_CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
echo "Configuring parallel processing:"
echo "  System cores: $NUM_CORES"
echo "  R will use: $IGP_CORES cores"
echo ""
echo "Analysis stage: $IGP_STAGE"
case "$IGP_STAGE" in
    1) echo "  (Setup & Initial QC - quick run)" ;;
    2) echo "  (Read IDATs & Correlations - 8-12 hours)" ;;
    3) echo "  (Replicate Analysis)" ;;
    4) echo "  (Full QC)" ;;
    5) echo "  (Complete Analysis)" ;;
esac
export MAKEFLAGS="-j${NUM_CORES}"
export MC_CORES="${NUM_CORES}"

# Get start time
start_time=$(date +%s)
echo "Started at: $(date)"
echo ""

# Run the analysis
echo "Rendering R Markdown file..."
echo "----------------------------------------"

# Set up R environment for parallel processing
RENDER_CMD="options(mc.cores = ${NUM_CORES}); library(parallel); rmarkdown::render('$RMD_PATH', output_file = 'igp_quality_control_20230222.html', output_dir = 'script')"

set +e
"${RSCRIPT_CMD[@]}" -e "$RENDER_CMD"
render_exit_code=$?
set -e

# Get end time
end_time=$(date +%s)
duration=$((end_time - start_time))
hours=$((duration / 3600))
minutes=$(((duration % 3600) / 60))

echo ""
echo "----------------------------------------"
echo "Completed at: $(date)"
echo "Duration: ${hours}h ${minutes}m"
echo ""

if [ $render_exit_code -ne 0 ]; then
    echo "✗ Analysis failed with exit code $render_exit_code"
    exit $render_exit_code
fi

echo "========================================="
echo "Checking Expected Outputs"
echo "========================================="
echo ""

# Expected outputs from Stage 1
expected_outputs=(
    "script/igp_quality_control_20230222.html:HTML report"
    "output/final_igp_data.rds:Final methylation data (720 MB)"
    "output/combatBetas.rds:Batch-corrected beta values (871 MB)"
    "output/snps.rds:SNP data"
    "output/meffil_qc_objects_20210924.Robj:meffil QC objects"
    "output/meffil_qc_summary_object_20210924.Robj:meffil QC summary"
    "output/raw_betas.rds:Raw beta values"
    "output/preprocessed_betas.rds:Preprocessed beta values"
    "output/noob_betas.rds:Noob normalized beta values"
    "output/zeroIntensityProbes.rds:Zero intensity probes"
    "output/igp_rgset_20211105.rds:RGChannelSet object"
)

echo "Expected outputs:"
missing_outputs=0
found_outputs=0

for output in "${expected_outputs[@]}"; do
    file="${output%%:*}"
    description="${output##*:}"

    if [ -f "$file" ]; then
        size=$(ls -lh "$file" | awk '{print $5}')
        echo "  ✓ $file ($size) - $description"
        found_outputs=$((found_outputs + 1))
    else
        echo "  ✗ $file - $description (NOT CREATED)"
        missing_outputs=$((missing_outputs + 1))
    fi
done

echo ""
echo "Summary:"
echo "  Found: $found_outputs/${#expected_outputs[@]} expected outputs"

if [ $missing_outputs -gt 0 ]; then
    echo "  ⚠ Warning: $missing_outputs expected files not created"
    echo ""
    echo "This may indicate:"
    echo "  - Analysis completed partially"
    echo "  - Some steps were skipped"
    echo "  - Errors occurred during processing"
    echo ""
    echo "Check the HTML report for details:"
    if [ -f "script/igp_quality_control_20230222.html" ]; then
        echo "  open script/igp_quality_control_20230222.html"
    fi
else
    echo "  ✓ All expected outputs created successfully"
fi

echo ""

# Restore original sample sheet if in test mode
if [ "$TEST_MODE" = true ]; then
    echo "Restoring original sample sheet..."
    if [ -f "data/cMulligan_SampleSheet160.csv.backup" ]; then
        mv data/cMulligan_SampleSheet160.csv.backup data/cMulligan_SampleSheet160.csv
        echo "✓ Original sample sheet restored"
    fi
    echo ""
fi

echo "========================================="
echo "Stage 1 Complete!"
echo "========================================="
echo ""

if [ "$TEST_MODE" = true ]; then
    echo "⚠ This was a TEST RUN with 4 samples only"
    echo "  Results are not representative of full analysis"
    echo ""
    echo "To run full analysis:"
    echo "  ./run_stage1.sh"
    echo ""
fi

if [ -f "script/igp_quality_control_20230222.html" ]; then
    echo "View QC report:"
    echo "  open script/igp_quality_control_20230222.html"
    echo ""
fi

echo "Next steps:"
echo "  1. Review QC report to check for issues"
echo "  2. Verify output files are correct sizes"
echo "  3. Proceed to Stage 2 (EWAS Analysis) if QC passes"
echo ""
echo "Key outputs for Stage 2:"
echo "  - output/final_igp_data.rds (720 MB)"
echo "  - output/combatBetas.rds (871 MB)"
