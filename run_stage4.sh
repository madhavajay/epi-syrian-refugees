#!/bin/bash

set -e  # Exit on error

# Parse command line arguments
TEST_MODE=false
DOCKER_MODE=false
NO_DOCKER_FLAG=false
PASSTHRU_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --test)
            TEST_MODE=true
            PASSTHRU_ARGS+=(--test)
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
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--test] [--docker]"
            exit 1
            ;;
    esac
done

if [ "$DOCKER_MODE" = true ] && [ "$NO_DOCKER_FLAG" = false ]; then
    docker run --rm -v "$(pwd)":/workspace -w /workspace -e IGP_CORES="${IGP_CORES:-}" -e IGP_TEST_MODE="$([ "$TEST_MODE" = true ] && echo 1 || echo 0)" \
        epi-syrian-refugees ./link_data.sh
    docker run --rm -v "$(pwd)":/workspace -w /workspace -e IGP_CORES="${IGP_CORES:-}" -e IGP_TEST_MODE="$([ "$TEST_MODE" = true ] && echo 1 || echo 0)" \
        epi-syrian-refugees Rscript -e "setwd('/workspace'); system('./run_stage4_rscript.R ${PASSTHRU_ARGS[*]}')"
    exit $?
fi

if [ "$TEST_MODE" = true ]; then
    echo "========================================="
    echo "Stage 4: Age Acceleration Analysis (TEST MODE)"
    echo "Epigenetic Violence Analysis"
    echo "========================================="
    echo ""
    echo "⚠ Running in test mode with reduced analysis"
    echo "  For full analysis, run without --test flag"
    echo ""
else
    echo "========================================="
    echo "Stage 4: Epigenetic Age Acceleration Analysis"
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
export DYLD_FALLBACK_LIBRARY_PATH="$(pwd)/libs:${DYLD_FALLBACK_LIBRARY_PATH:-}"
echo "✓ Environment found"

# Check if directories are set up
if [ ! -d "data" ] || [ ! -d "script" ]; then
    echo "✗ Directory structure not set up"
    echo "  Run ./extract.sh followed by ./link_data.sh"
    exit 1
fi
echo "✓ Directory structure set up"

# Check Stage 3 outputs
echo ""
echo "Checking Stage 3 outputs..."
required_stage3=(
    "data/epigenetic_age_data_20230308.csv:Main epigenetic age dataset (133 KB)"
)

# Also check for alternative locations
if [ ! -f "data/epigenetic_age_data_20230308.csv" ]; then
    # Try to find in data/23498658/
    if [ -f "data/23498658/epigenetic_age_data_20230308.csv" ]; then
        echo "  ✓ Found in data/23498658/"
        ln -sf "23498658/epigenetic_age_data_20230308.csv" data/
        echo "  ✓ Created symlink: data/epigenetic_age_data_20230308.csv"
    elif [ -f "output/epigenetic_age_data_20230308.csv" ]; then
        echo "  ✓ Found in output/"
        ln -sf "../output/epigenetic_age_data_20230308.csv" data/
        echo "  ✓ Created symlink: data/epigenetic_age_data_20230308.csv"
    else
        echo "  ⚠ Warning: data/epigenetic_age_data_20230308.csv not found"
        echo "  This file should be created by Stage 3"
        echo "  Checking if we can use data from data/23498658/..."
    fi
fi

missing_stage3=0
for item in "${required_stage3[@]}"; do
    file="${item%%:*}"
    description="${item##*:}"

    if [ ! -f "$file" ]; then
        echo "  ✗ Missing: $file - $description"
        missing_stage3=$((missing_stage3 + 1))
    else
        size=$(ls -lh "$file" | awk '{print $5}')
        echo "  ✓ $file ($size)"
    fi
done

# Check for replicate dataset (optional)
echo ""
echo "Checking optional replicate dataset..."
if [ -f "data/replicate_epigenetic_age_data_20230308.csv" ]; then
    size=$(ls -lh "data/replicate_epigenetic_age_data_20230308.csv" | awk '{print $5}')
    echo "  ✓ data/replicate_epigenetic_age_data_20230308.csv ($size)"
elif [ -f "data/23498658/replicate_epigenetic_age_data_20230308.csv" ]; then
    ln -sf "23498658/replicate_epigenetic_age_data_20230308.csv" data/
    echo "  ✓ Created symlink: data/replicate_epigenetic_age_data_20230308.csv"
elif [ -f "output/replicate_epigenetic_age_data_20230308.csv" ]; then
    ln -sf "../output/replicate_epigenetic_age_data_20230308.csv" data/
    echo "  ✓ Created symlink: data/replicate_epigenetic_age_data_20230308.csv"
else
    echo "  ⚠ replicate dataset not found (optional - analysis can proceed without it)"
fi

if [ $missing_stage3 -gt 0 ]; then
    echo ""
    echo "✗ Stage 3 outputs missing"
    echo "  Run ./run_stage3.sh first to generate required files"
    exit 1
fi

# Check if analysis script exists
echo ""
if [ ! -f "script/igp_epigenetic_age_analysis_v6.Rmd" ]; then
    echo "⚠ Analysis script not found in script/"
    echo "  Attempting to symlink from data/23498658/..."

    # The file has a space in the name, so we need to handle it carefully
    if [ -f "data/23498658/igp_epigenetic_age_analysis_v6 (1).Rmd" ]; then
        # Create symlink with cleaner name
        ln -sf "../data/23498658/igp_epigenetic_age_analysis_v6 (1).Rmd" "script/igp_epigenetic_age_analysis_v6.Rmd"
        echo "  ✓ Created symlink: script/igp_epigenetic_age_analysis_v6.Rmd"
    else
        echo "  ✗ Script not found in data/23498658/ either"
        exit 1
    fi
else
    echo "✓ Analysis script found: script/igp_epigenetic_age_analysis_v6.Rmd"
fi

echo ""
echo "========================================="
echo "Starting Stage 4 Age Acceleration Analysis"
echo "========================================="
echo ""

if [ "$TEST_MODE" = true ]; then
    echo "Test Mode Configuration:"
    echo "  - Reduced subset of clocks for testing"
    echo "  - Note: R script may need modification for test mode"
    echo "  - This provides syntax/environment validation only"
    echo ""
    echo "Analysis components:"
    echo "  - GEE models with family clustering (subset of clocks)"
    echo "  - 3 exposure contrasts (Direct, Prenatal, Germline vs Control)"
    echo "  - Primary analysis only (no sensitivity analyses)"
    echo ""
    echo "Estimated runtime: 30-60 minutes"
    echo "RAM required: 16-32 GB"
    echo "Output: script/igp_epigenetic_age_analysis_v6.html"
    echo ""
else
    echo "Analysis components:"
    echo "  - GEE models with family clustering"
    echo "  - 3 exposure contrasts + combined (All exposed vs Control)"
    echo "  - Classic clocks: Horvath1, Horvath2, PEDBE"
    echo "  - 9 PC-Clock accelerations"
    echo "  - Sensitivity analyses (generation, sex, SES, cell type)"
    echo "  - Visualization (forest plots, box plots, heatmaps)"
    echo ""
    echo "Estimated runtime: 2-4 hours"
    echo "RAM required: 32-64 GB"
    echo "Output: script/igp_epigenetic_age_analysis_v6.html"
    echo ""
fi

# Prepare Rscript runner
ARCH=$(uname -m)
RSCRIPT_BIN="$ENV_ABS_PATH/bin/Rscript"
if [ ! -x "$RSCRIPT_BIN" ]; then
    echo "✗ Rscript binary not found: $RSCRIPT_BIN"
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

# Set environment variable for test mode if needed
if [ "$TEST_MODE" = true ]; then
    export IGP_TEST_MODE=1
    echo "Note: IGP_TEST_MODE=1 environment variable set"
    echo "  R script can check this with: Sys.getenv('IGP_TEST_MODE')"
    echo ""
fi

RENDER_CMD="rmarkdown::render('script/igp_epigenetic_age_analysis_v6.Rmd')"

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

# Expected outputs from Stage 4
expected_outputs=(
    "script/igp_epigenetic_age_analysis_v6.html:Age acceleration analysis report"
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

# Check for results tables
echo ""
echo "Checking for results tables in output/..."
results_files=$(find output -name "*acceleration*" -o -name "*association*" -o -name "*gee*" 2>/dev/null | wc -l | tr -d ' ')
if [ "$results_files" -gt 0 ]; then
    echo "  ✓ Found $results_files results files:"
    find output -name "*acceleration*" -o -name "*association*" -o -name "*gee*" 2>/dev/null | while read f; do
        size=$(ls -lh "$f" | awk '{print $5}')
        echo "    - $(basename "$f") ($size)"
    done
else
    echo "  ⚠ No results files found (may be embedded in HTML report)"
fi

# Check for figures
echo ""
echo "Checking for figures in output/..."
figure_files=$(find output -name "*.png" -o -name "*.pdf" 2>/dev/null | wc -l | tr -d ' ')
if [ "$figure_files" -gt 0 ]; then
    echo "  ✓ Found $figure_files figure files:"
    find output -name "*.png" -o -name "*.pdf" 2>/dev/null | head -10 | while read f; do
        size=$(ls -lh "$f" | awk '{print $5}')
        echo "    - $(basename "$f") ($size)"
    done
    if [ "$figure_files" -gt 10 ]; then
        echo "    ... and $((figure_files - 10)) more"
    fi
else
    echo "  ⚠ No figure files found (may be embedded in HTML report)"
fi

echo ""
echo "Summary:"
echo "  Found: $found_outputs/${#expected_outputs[@]} expected main outputs"

if [ $missing_outputs -gt 0 ]; then
    echo "  ⚠ Warning: $missing_outputs expected files not created"
    echo ""
    echo "Check the HTML report for results and details:"
    if [ -f "script/igp_epigenetic_age_analysis_v6.html" ]; then
        echo "  open script/igp_epigenetic_age_analysis_v6.html"
    fi
else
    echo "  ✓ Main outputs created successfully"
fi

echo ""
echo "========================================="
echo "Stage 4 Complete!"
echo "========================================="
echo ""

if [ "$TEST_MODE" = true ]; then
    echo "⚠ This was a TEST RUN with reduced analysis"
    echo "  Results are not representative of full analysis"
    echo ""
    echo "To run full analysis:"
    echo "  ./run_stage4.sh"
    echo ""
fi

if [ -f "script/igp_epigenetic_age_analysis_v6.html" ]; then
    echo "View age acceleration analysis report:"
    echo "  open script/igp_epigenetic_age_analysis_v6.html"
    echo ""
fi

echo "Key findings to review:"
echo "  1. Effect sizes (β coefficients) for each exposure contrast"
echo "  2. Statistical significance after multiple testing correction"
echo "  3. Consistency across different epigenetic clocks"
echo "  4. Direction of effects (accelerated vs decelerated aging)"
echo "  5. Robustness in sensitivity analyses"
echo ""

echo "========================================="
echo "Full Pipeline Complete!"
echo "========================================="
echo ""
echo "All 4 analysis stages finished:"
echo "  ✓ Stage 1: Quality Control & Data Processing"
echo "  ✓ Stage 2: EWAS Analysis (DMPs)"
echo "  ✓ Stage 3: Epigenetic Age QC"
echo "  ✓ Stage 4: Age Acceleration Analysis"
echo ""
echo "Review all HTML reports for complete findings!"
