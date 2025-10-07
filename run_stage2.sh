#!/bin/bash

set -e  # Exit on error

# Parse command line arguments
TEST_MODE=false
if [[ "$1" == "--test" ]]; then
    TEST_MODE=true
    echo "========================================="
    echo "Stage 2: EWAS Analysis (TEST MODE)"
    echo "Epigenetic Violence Analysis"
    echo "========================================="
    echo ""
    echo "⚠ Running in test mode with reduced probe set"
    echo "  For full analysis, run without --test flag"
    echo ""
else
    echo "========================================="
    echo "Stage 2: EWAS Analysis"
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

# Check if Stage 1 outputs exist
echo ""
echo "Checking Stage 1 outputs..."
required_stage1=(
    "output/final_igp_data.rds:Final methylation data (720 MB)"
    "output/combatBetas.rds:Batch-corrected beta values (871 MB)"
)

missing_stage1=0
for item in "${required_stage1[@]}"; do
    file="${item%%:*}"
    description="${item##*:}"

    if [ ! -f "$file" ]; then
        echo "  ✗ Missing: $file - $description"
        missing_stage1=$((missing_stage1 + 1))
    else
        size=$(ls -lh "$file" | awk '{print $5}')
        echo "  ✓ $file ($size)"
    fi
done

if [ $missing_stage1 -gt 0 ]; then
    echo ""
    echo "✗ Stage 1 outputs missing"
    echo "  Run ./run_stage1.sh first to generate required files"
    exit 1
fi

# Check for igp_methylation_special.rds
echo ""
echo "Checking for methylation subset..."
if [ ! -f "data/igp_methylation_special.rds" ]; then
    echo "⚠ Warning: data/igp_methylation_special.rds not found"
    echo "  This file may need to be created from final_igp_data.rds"
    echo "  Checking if we can symlink from data/22183384/..."

    if [ -f "data/22183384/igp_methylation_special.rds" ]; then
        ln -sf "22183384/igp_methylation_special.rds" data/igp_methylation_special.rds
        echo "  ✓ Created symlink to data/22183384/igp_methylation_special.rds"
    else
        echo "  ⚠ File not found in data/22183384/ either"
        echo "  The script may create this or use final_igp_data.rds instead"
    fi
else
    echo "✓ data/igp_methylation_special.rds found"
fi

# Check Stage 2 input files
echo ""
echo "Checking Stage 2 input files..."
required_files=(
    "data/IGP_Epi_Metadata_20221016.csv:Exposure metadata"
    "data/igp_demo_special.csv:Demographics subset"
    "output/EPIC.hg38.manifest.tsv:hg38 probe mappings (272 MB)"
    "output/EPIC.hg38.manifest.gencode.v36.tsv:Gene annotations (252 MB)"
    "supp_data/infinium-methylationepic-v-1-0-b5-manifest-file.csv:EPIC manifest (522 MB)"
)

missing_files=0
for item in "${required_files[@]}"; do
    file="${item%%:*}"
    description="${item##*:}"

    if [ ! -f "$file" ]; then
        # Try to symlink from data/22183384/
        source_file="data/22183384/$(basename "$file")"
        if [ -f "$source_file" ]; then
            target_dir=$(dirname "$file")
            ln -sf "../22183384/$(basename "$file")" "$file"
            echo "  ✓ Created symlink: $file"
        else
            echo "  ✗ Missing: $file - $description"
            missing_files=$((missing_files + 1))
        fi
    else
        echo "  ✓ $file"
    fi
done

if [ $missing_files -gt 0 ]; then
    echo ""
    echo "✗ $missing_files required files missing"
    echo "  Ensure data/22183384/ directory is extracted"
    exit 1
fi

# Check if analysis script exists
echo ""
if [ ! -f "script/IGP_HiperGator_Code_v24.Rmd" ]; then
    echo "⚠ Analysis script not found in script/"
    echo "  Attempting to symlink from data/22183384/..."

    if [ -f "data/22183384/IGP_HiperGator_Code_v24.Rmd" ]; then
        ln -sf "../data/22183384/IGP_HiperGator_Code_v24.Rmd" script/
        echo "  ✓ Created symlink: script/IGP_HiperGator_Code_v24.Rmd"
    else
        echo "  ✗ Script not found in data/22183384/ either"
        exit 1
    fi
else
    echo "✓ Analysis script found: script/IGP_HiperGator_Code_v24.Rmd"
fi

echo ""
echo "========================================="
echo "Starting Stage 2 EWAS Analysis"
echo "========================================="
echo ""

if [ "$TEST_MODE" = true ]; then
    echo "Test Mode Configuration:"
    echo "  - Will use subset of probes for faster testing"
    echo "  - Note: R script may need modification for test mode"
    echo "  - This provides syntax/environment validation only"
    echo ""
    echo "Analysis components:"
    echo "  - 3 exposure contrasts (Direct, Prenatal, Germline vs Control)"
    echo "  - Robust linear regression (Stage 1) - subset of probes"
    echo "  - GEE models with family clustering (Stage 2) - subset"
    echo "  - DMP identification (reduced significance threshold)"
    echo ""
    echo "Estimated runtime: 1-2 hours"
    echo "RAM required: 32-64 GB"
    echo "Output: script/IGP_HiperGator_Code_v24.html"
    echo ""
else
    echo "Analysis components:"
    echo "  - 3 exposure contrasts (Direct, Prenatal, Germline vs Control)"
    echo "  - Robust linear regression (Stage 1)"
    echo "  - GEE models with family clustering (Stage 2)"
    echo "  - DMP identification (Bonferroni: p < 6.505×10⁻⁸)"
    echo "  - GO enrichment analysis"
    echo ""
    echo "Estimated runtime: 12-24 hours"
    echo "RAM required: 128 GB"
    echo "Output: script/IGP_HiperGator_Code_v24.html"
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

# Set environment variable for test mode if needed
if [ "$TEST_MODE" = true ]; then
    export IGP_TEST_MODE=1
    echo "Note: IGP_TEST_MODE=1 environment variable set"
    echo "  R script can check this with: Sys.getenv('IGP_TEST_MODE')"
    echo ""
fi

if [[ "$ARCH" == "arm64" ]]; then
    arch -x86_64 Rscript -e "rmarkdown::render('script/IGP_HiperGator_Code_v24.Rmd')"
else
    Rscript -e "rmarkdown::render('script/IGP_HiperGator_Code_v24.Rmd')"
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

# Expected outputs from Stage 2
expected_outputs=(
    "script/IGP_HiperGator_Code_v24.html:EWAS results report (13 MB)"
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

# Check for DMP output files (names may vary)
echo ""
echo "Checking for DMP output files in output/..."
dmp_files=$(find output -name "*DMP*" -o -name "*dmp*" -o -name "*significant*" 2>/dev/null | wc -l | tr -d ' ')
if [ "$dmp_files" -gt 0 ]; then
    echo "  ✓ Found $dmp_files DMP-related files:"
    find output -name "*DMP*" -o -name "*dmp*" -o -name "*significant*" 2>/dev/null | while read f; do
        size=$(ls -lh "$f" | awk '{print $5}')
        echo "    - $(basename "$f") ($size)"
    done
else
    echo "  ⚠ No DMP files found (may be embedded in HTML report)"
fi

# Check for GO enrichment files
echo ""
echo "Checking for GO enrichment files in output/..."
go_files=$(find output -name "*GO*" -o -name "*enrich*" -o -name "*pathway*" 2>/dev/null | wc -l | tr -d ' ')
if [ "$go_files" -gt 0 ]; then
    echo "  ✓ Found $go_files GO enrichment files:"
    find output -name "*GO*" -o -name "*enrich*" -o -name "*pathway*" 2>/dev/null | while read f; do
        size=$(ls -lh "$f" | awk '{print $5}')
        echo "    - $(basename "$f") ($size)"
    done
else
    echo "  ⚠ No GO enrichment files found (may be embedded in HTML report)"
fi

echo ""
echo "Summary:"
echo "  Found: $found_outputs/${#expected_outputs[@]} expected main outputs"

if [ $missing_outputs -gt 0 ]; then
    echo "  ⚠ Warning: $missing_outputs expected files not created"
    echo ""
    echo "Check the HTML report for results and details:"
    if [ -f "script/IGP_HiperGator_Code_v24.html" ]; then
        echo "  open script/IGP_HiperGator_Code_v24.html"
    fi
else
    echo "  ✓ Main outputs created successfully"
fi

echo ""
echo "========================================="
echo "Stage 2 Complete!"
echo "========================================="
echo ""

if [ -f "script/IGP_HiperGator_Code_v24.html" ]; then
    echo "View EWAS results:"
    echo "  open script/IGP_HiperGator_Code_v24.html"
    echo ""
fi

echo "Key findings to review:"
echo "  - Number of significant DMPs per contrast"
echo "  - Direction of methylation changes (hyper/hypo)"
echo "  - Enriched biological pathways"
echo "  - Overlap between exposure groups"
echo ""

echo "Next steps:"
echo "  1. Review EWAS report for significant findings"
echo "  2. Check DMP tables for effect sizes and p-values"
echo "  3. Examine GO enrichment results"
echo "  4. Proceed to Stage 3 (Epigenetic Age QC) if results look good"
