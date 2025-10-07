#!/bin/bash

set -e  # Exit on error

# Parse command line arguments
TEST_MODE=false
if [[ "$1" == "--test" ]]; then
    TEST_MODE=true
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
RMD_PATH_TEST="script/igp_quality_control_20230222_test.Rmd"
RMD_PATH="$RMD_PATH_BASE"
export IGP_CORES=${IGP_CORES:-8}
export IGP_TEST_MODE=0
export DYLD_FALLBACK_LIBRARY_PATH="$(pwd)/libs:${DYLD_FALLBACK_LIBRARY_PATH:-}"
IDAT_DOWNLOAD_DIR="$(pwd)/downloads/idat"
echo "✓ Environment found"

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
    echo "  Run ./link_data.sh to create symlinks"
    exit 1
fi
echo "✓ Analysis script found"

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
                ln -sf "$IDAT_DOWNLOAD_DIR/$base_name" "data/${trimmed_name}"

                trimmed_no_gz="${trimmed_name%.gz}"
                if [[ "$trimmed_no_gz" != "$trimmed_name" ]]; then
                    ln -sf "$IDAT_DOWNLOAD_DIR/$base_name" "data/${trimmed_no_gz}"
                fi
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

# Get start time
start_time=$(date +%s)
echo "Started at: $(date)"
echo ""

# Run the analysis
echo "Rendering R Markdown file..."
echo "----------------------------------------"

RENDER_CMD="rmarkdown::render('$RMD_PATH', output_file = 'igp_quality_control_20230222.html', output_dir = 'script')"

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
