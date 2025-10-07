#!/bin/bash

set -e  # Exit on error

# Parse command line arguments
TEST_MODE=false
if [[ "$1" == "--test" ]]; then
    TEST_MODE=true
    echo "========================================="
    echo "Stage 3: Epigenetic Age QC (TEST MODE)"
    echo "Epigenetic Violence Analysis"
    echo "========================================="
    echo ""
    echo "⚠ Running in test mode with 2 samples only"
    echo "  For full analysis, run without --test flag"
    echo ""
else
    echo "========================================="
    echo "Stage 3: Epigenetic Age Quality Control"
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
if [ ! -d "data" ] || [ ! -d "output" ] || [ ! -d "script" ] || [ ! -d "supp_data" ]; then
    echo "✗ Directory structure not set up"
    echo "  Run ./extract.sh followed by ./link_data.sh"
    exit 1
fi
echo "✓ Directory structure set up"

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

# Check Stage 3 input files
echo ""
echo "Checking Stage 3 input files..."
required_files=(
    "data/cMulligan_SampleSheet160.csv:Sample sheet"
    "supp_data/cMulligan_SampleManifest160.csv:Sample manifest"
    "supp_data/igp_ages.csv:Age data"
    "supp_data/IGP_SwabType.csv:Swab type data"
    "output/igp_horvath_betas_20211104.csv:Horvath beta values (79 MB)"
    "output/igp_horvath_betas_20211104.output.csv:Horvath clock output"
)

missing_files=0
for item in "${required_files[@]}"; do
    file="${item%%:*}"
    description="${item##*:}"

    if [ ! -f "$file" ]; then
        # Try to symlink from data/23498670/
        source_file="data/23498670/$(basename "$file")"
        if [ -f "$source_file" ]; then
            target_dir=$(dirname "$file")
            ln -sf "../23498670/$(basename "$file")" "$file"
            echo "  ✓ Created symlink: $file"
        else
            echo "  ✗ Missing: $file - $description"
            missing_files=$((missing_files + 1))
        fi
    else
        echo "  ✓ $file"
    fi
done

# Check PC-Clocks resources
echo ""
echo "Checking PC-Clocks resources..."
pc_files=(
    "data/23498670/CalcAllPCClocks.RData:PC-Clocks model data (2.2 GB)"
    "data/23498670/run_calcPCClocks.R:PC-Clocks calculation function"
    "data/23498670/run_calcPCClocks_Accel.R:Acceleration calculation"
)

missing_pc=0
for item in "${pc_files[@]}"; do
    file="${item%%:*}"
    description="${item##*:}"

    if [ ! -f "$file" ]; then
        echo "  ✗ Missing: $file - $description"
        missing_pc=$((missing_pc + 1))
    else
        size=$(ls -lh "$file" | awk '{print $5}')
        echo "  ✓ $file ($size)"
    fi
done

if [ $missing_files -gt 0 ] || [ $missing_pc -gt 0 ]; then
    total_missing=$((missing_files + missing_pc))
    echo ""
    echo "✗ $total_missing required files missing"
    echo "  Ensure data/23498670/ directory is extracted"
    exit 1
fi

# Check if analysis script exists
echo ""
if [ ! -f "script/igp_epigenetic_age_quality_control_20230611.Rmd" ]; then
    echo "⚠ Analysis script not found in script/"
    echo "  Attempting to symlink from data/23498670/..."

    if [ -f "data/23498670/igp_epigenetic_age_quality_control_20230611.Rmd" ]; then
        ln -sf "../data/23498670/igp_epigenetic_age_quality_control_20230611.Rmd" script/
        echo "  ✓ Created symlink: script/igp_epigenetic_age_quality_control_20230611.Rmd"
    else
        echo "  ✗ Script not found in data/23498670/ either"
        exit 1
    fi
else
    echo "✓ Analysis script found: script/igp_epigenetic_age_quality_control_20230611.Rmd"
fi

# Symlink PC-Clocks helper scripts to script/ directory
echo ""
echo "Setting up PC-Clocks helper scripts..."
for helper in run_calcPCClocks.R run_calcPCClocks_Accel.R; do
    if [ ! -f "script/$helper" ]; then
        if [ -f "data/23498670/$helper" ]; then
            ln -sf "../data/23498670/$helper" script/
            echo "  ✓ Symlinked: script/$helper"
        fi
    else
        echo "  ✓ script/$helper exists"
    fi
done

echo ""
echo "========================================="
echo "Starting Stage 3 Epigenetic Age QC"
echo "========================================="
echo ""

# Set up test mode if requested
if [ "$TEST_MODE" = true ]; then
    echo "Test Mode Configuration:"
    echo "  - Using test sample sheet (2 samples)..."

    # Create test sample sheet if needed
    if [ ! -f "data/cMulligan_SampleSheet_test.csv" ]; then
        ./create_test_samplesheet.sh
    fi

    # Backup original and use test version
    if [ ! -f "data/cMulligan_SampleSheet160.csv.backup" ]; then
        cp data/cMulligan_SampleSheet160.csv data/cMulligan_SampleSheet160.csv.backup
    fi
    cp data/cMulligan_SampleSheet_test.csv data/cMulligan_SampleSheet160.csv

    echo ""
    echo "Analysis components:"
    echo "  - SeSAMe normalization (2 samples)"
    echo "  - Classic clocks: Horvath1, Horvath2, PEDBE"
    echo "  - 14 PC-Clocks (PCHorvath1, PCGrimAge, etc.)"
    echo "  - Age acceleration calculation"
    echo ""
    echo "Estimated runtime: 30-60 minutes"
    echo "RAM required: 16-32 GB"
    echo "Output: script/igp_epigenetic_age_quality_control_20230611.html"
    echo ""
else
    echo "Analysis components:"
    echo "  - SeSAMe normalization (160 samples)"
    echo "  - Classic clocks: Horvath1, Horvath2, PEDBE"
    echo "  - 14 PC-Clocks (PCHorvath1, PCGrimAge, etc.)"
    echo "  - Age acceleration calculation"
    echo "  - QC plots and correlation analysis"
    echo ""
    echo "Estimated runtime: 8-12 hours"
    echo "RAM required: 128 GB"
    echo "Output: script/igp_epigenetic_age_quality_control_20230611.html"
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
    arch -x86_64 Rscript -e "rmarkdown::render('script/igp_epigenetic_age_quality_control_20230611.Rmd')"
else
    Rscript -e "rmarkdown::render('script/igp_epigenetic_age_quality_control_20230611.Rmd')"
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

# Expected outputs from Stage 3
expected_outputs=(
    "script/igp_epigenetic_age_quality_control_20230611.html:Epigenetic age QC report"
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

# Check for epigenetic age data files
echo ""
echo "Checking for epigenetic age data files in output/..."
age_files=$(find output -name "*epigenetic_age*" -o -name "*pc_clock*" -o -name "*horvath*" 2>/dev/null | wc -l | tr -d ' ')
if [ "$age_files" -gt 0 ]; then
    echo "  ✓ Found $age_files epigenetic age data files:"
    find output -name "*epigenetic_age*" -o -name "*pc_clock*" -o -name "*horvath*" 2>/dev/null | while read f; do
        size=$(ls -lh "$f" | awk '{print $5}')
        echo "    - $(basename "$f") ($size)"
    done
else
    echo "  ⚠ No epigenetic age data files found (may be embedded in HTML report)"
fi

echo ""
echo "Summary:"
echo "  Found: $found_outputs/${#expected_outputs[@]} expected main outputs"

if [ $missing_outputs -gt 0 ]; then
    echo "  ⚠ Warning: $missing_outputs expected files not created"
    echo ""
    echo "Check the HTML report for results and details:"
    if [ -f "script/igp_epigenetic_age_quality_control_20230611.html" ]; then
        echo "  open script/igp_epigenetic_age_quality_control_20230611.html"
    fi
else
    echo "  ✓ Main outputs created successfully"
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
echo "Stage 3 Complete!"
echo "========================================="
echo ""

if [ "$TEST_MODE" = true ]; then
    echo "⚠ This was a TEST RUN with 2 samples only"
    echo "  Results are not representative of full analysis"
    echo ""
    echo "To run full analysis:"
    echo "  ./run_stage3.sh"
    echo ""
fi

if [ -f "script/igp_epigenetic_age_quality_control_20230611.html" ]; then
    echo "View epigenetic age QC report:"
    echo "  open script/igp_epigenetic_age_quality_control_20230611.html"
    echo ""
fi

echo "Next steps:"
echo "  1. Review QC report for epigenetic age predictions"
echo "  2. Check age prediction R² values (expect > 0.7)"
echo "  3. Verify PC-Clocks calculated successfully"
echo "  4. Proceed to Stage 4 (Age Acceleration Analysis) if QC passes"
echo ""
echo "Key outputs for Stage 4:"
echo "  - Epigenetic age dataset with all clocks + acceleration metrics"
echo "  - Expected: epigenetic_age_data_*.csv (~140 KB)"
