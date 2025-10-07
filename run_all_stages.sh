#!/bin/bash

set -e  # Exit on error

# Parse command line arguments
TEST_MODE=false
STAGE=""
DOCKER_MODE=false
PASSTHRU_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --test)
            TEST_MODE=true
            PASSTHRU_ARGS+=(--test)
            shift
            ;;
        --stage)
            STAGE="$2"
            PASSTHRU_ARGS+=(--stage "$2")
            shift 2
            ;;
        --docker)
            DOCKER_MODE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--test] [--stage N] [--docker]"
            echo "  --test: Run in test mode (faster, reduced datasets)"
            echo "  --stage N: Run only stage N (1-4), otherwise runs all stages"
            echo "  --docker: Execute inside epi-syrian-refugees Docker image"
            exit 1
            ;;
    esac
done

if [ "$DOCKER_MODE" = true ]; then
    docker run --rm -v "$(pwd)":/workspace -w /workspace -e IGP_CORES="${IGP_CORES:-}" \
        epi-syrian-refugees ./link_data.sh
    docker run --rm -v "$(pwd)":/workspace -w /workspace -e IGP_CORES="${IGP_CORES:-}" \
        epi-syrian-refugees ./run_all_stages.sh "${PASSTHRU_ARGS[@]}"
    exit $?
fi

echo "========================================="
echo "Syrian Refugee Epigenetic Violence Study"
echo "Complete Analysis Pipeline"
echo "========================================="
echo ""

if [ "$TEST_MODE" = true ]; then
    echo "⚠ Running in TEST MODE"
    echo "  All stages will use reduced datasets for quick validation"
    echo ""
fi

if [ -n "$STAGE" ]; then
    echo "Running Stage $STAGE only"
    echo ""
else
    echo "Running all 4 analysis stages sequentially"
    echo ""
fi

# Function to run a stage
run_stage() {
    local stage_num=$1
    local stage_name=$2
    local script=$3

    echo ""
    echo "========================================"
    echo "STAGE $stage_num: $stage_name"
    echo "========================================"
    echo ""

    if [ "$TEST_MODE" = true ]; then
        ./$script --test
    else
        ./$script
    fi

    stage_exit=$?
    if [ $stage_exit -ne 0 ]; then
        echo ""
        echo "✗ Stage $stage_num failed with exit code $stage_exit"
        echo "  Fix errors before proceeding to next stage"
        exit $stage_exit
    fi

    echo ""
    echo "✓ Stage $stage_num completed successfully"
    echo ""
}

# Overall start time
overall_start=$(date +%s)
echo "Pipeline started at: $(date)"
echo ""

# Run requested stages
if [ -z "$STAGE" ] || [ "$STAGE" = "1" ]; then
    run_stage 1 "Quality Control & Data Processing" "run_stage1.sh"
fi

if [ -z "$STAGE" ] || [ "$STAGE" = "2" ]; then
    run_stage 2 "EWAS Analysis" "run_stage2.sh"
fi

if [ -z "$STAGE" ] || [ "$STAGE" = "3" ]; then
    run_stage 3 "Epigenetic Age QC" "run_stage3.sh"
fi

if [ -z "$STAGE" ] || [ "$STAGE" = "4" ]; then
    run_stage 4 "Age Acceleration Analysis" "run_stage4.sh"
fi

# Overall end time
overall_end=$(date +%s)
overall_duration=$((overall_end - overall_start))
overall_hours=$((overall_duration / 3600))
overall_minutes=$(((overall_duration % 3600) / 60))

echo ""
echo "========================================"
echo "PIPELINE COMPLETE!"
echo "========================================"
echo ""
echo "Finished at: $(date)"
echo "Total duration: ${overall_hours}h ${overall_minutes}m"
echo ""

if [ "$TEST_MODE" = true ]; then
    echo "⚠ This was a TEST RUN"
    echo "  Results are not representative of full analysis"
    echo ""
    echo "To run full pipeline:"
    echo "  ./run_all_stages.sh"
    echo ""
fi

echo "Generated HTML reports:"
if [ -z "$STAGE" ] || [ "$STAGE" = "1" ]; then
    [ -f "script/igp_quality_control_20230222.html" ] && echo "  - script/igp_quality_control_20230222.html (Stage 1 QC)"
fi
if [ -z "$STAGE" ] || [ "$STAGE" = "2" ]; then
    [ -f "script/IGP_HiperGator_Code_v24.html" ] && echo "  - script/IGP_HiperGator_Code_v24.html (Stage 2 EWAS)"
fi
if [ -z "$STAGE" ] || [ "$STAGE" = "3" ]; then
    [ -f "script/igp_epigenetic_age_quality_control_20230611.html" ] && echo "  - script/igp_epigenetic_age_quality_control_20230611.html (Stage 3 Age QC)"
fi
if [ -z "$STAGE" ] || [ "$STAGE" = "4" ]; then
    [ -f "script/igp_epigenetic_age_analysis_v6.html" ] && echo "  - script/igp_epigenetic_age_analysis_v6.html (Stage 4 Acceleration)"
fi

echo ""
echo "Next steps:"
echo "  1. Review all HTML reports for quality and results"
echo "  2. Check output/ directory for data files and figures"
echo "  3. Compare results with published paper findings"
echo "  4. Document any discrepancies or issues"
