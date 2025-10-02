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
    echo "⚠ Running in test mode with 2 samples only"
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
echo "✓ Environment found"

# Check if directories are set up
if [ ! -d "supp_data" ] || [ ! -d "output" ] || [ ! -d "script" ]; then
    echo "✗ Directory structure not set up"
    echo "  Run ./extract.sh first"
    exit 1
fi
echo "✓ Directory structure set up"

# Check if analysis script exists
if [ ! -f "script/igp_quality_control_20230222.Rmd" ]; then
    echo "✗ Analysis script not found: script/igp_quality_control_20230222.Rmd"
    echo "  Run ./extract.sh to create symlinks"
    exit 1
fi
echo "✓ Analysis script found"

# Check IDAT files
idat_count=$(find data -maxdepth 1 -name "*.idat.gz" 2>/dev/null | wc -l | tr -d ' ')

if [ "$TEST_MODE" = true ]; then
    # In test mode, we only need 4 IDAT files (2 samples × 2 channels)
    if [ "$idat_count" -lt 4 ]; then
        echo "✗ Not enough IDAT files for test mode"
        echo "  Need at least 4 files (2 samples × 2 channels), found $idat_count"
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
    echo "  Run ./extract.sh to set up symlinks"
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
    echo "  - Creating test sample sheet (2 samples)..."

    # Create test sample sheet
    ./create_test_samplesheet.sh

    # Backup original and use test version
    if [ ! -f "data/cMulligan_SampleSheet160.csv.backup" ]; then
        cp data/cMulligan_SampleSheet160.csv data/cMulligan_SampleSheet160.csv.backup
    fi
    cp data/cMulligan_SampleSheet_test.csv data/cMulligan_SampleSheet160.csv

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

# Activate environment
eval "$(micromamba shell hook --shell bash)"
micromamba activate "$ENV_DIR"

# Check architecture and set up x86_64 if needed
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
    export CONDA_SUBDIR=osx-64
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

if [[ "$ARCH" == "arm64" ]]; then
    arch -x86_64 Rscript -e "rmarkdown::render('script/igp_quality_control_20230222.Rmd')"
else
    Rscript -e "rmarkdown::render('script/igp_quality_control_20230222.Rmd')"
fi

render_exit_code=$?

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
    echo "⚠ This was a TEST RUN with 2 samples only"
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
