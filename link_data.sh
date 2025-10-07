#!/bin/bash

set -e  # Exit on error

echo "========================================="
echo "Setting up directory structure and symlinks"
echo "========================================="
echo ""

# Ensure required directories exist
mkdir -p data supp_data output script

echo "Step 1: Creating metadata and script symlinks"
echo ""

SOURCE_DIR="data/22183534"
if [ ! -d "$SOURCE_DIR" ]; then
    echo "✗ Expected source directory $SOURCE_DIR not found"
    echo "  Run ./extract.sh first to unpack the raw data"
    exit 1
fi
SOURCE_ABS=$(cd "$SOURCE_DIR" && pwd)

ln -sf "../${SOURCE_DIR}/cMulligan_SampleManifest160.csv" supp_data/
ln -sf "../${SOURCE_DIR}/IGP_SwabType.csv" supp_data/
ln -sf "../${SOURCE_DIR}/igp_ages.csv" supp_data/
ln -sf "../${SOURCE_DIR}/datMiniAnnotation3.csv" supp_data/
ln -sf "../${SOURCE_DIR}/IGP_Epi_Metadata20220330.csv" supp_data/
ln -sf "../${SOURCE_DIR}/all_samples_log_compiled_20220106.csv" supp_data/
ln -sf "../${SOURCE_DIR}/igp_relatedness_coded_20220105.csv" supp_data/
ln -sf "../${SOURCE_DIR}/infinium-methylationepic-v-1-0-b5-manifest-file.csv" supp_data/

echo "  ✓ Metadata symlinks refreshed"

echo ""
echo "Step 2: Linking sample sheet, Horvath outputs, and scripts"
echo ""

ln -sf "$SOURCE_ABS/cMulligan_SampleSheet160.csv" data/
ln -sf "$SOURCE_ABS/igp_horvath_betas_20211104.csv" output/
ln -sf "$SOURCE_ABS/igp_horvath_samplesheet_20211104.csv" output/
ln -sf "$SOURCE_ABS/igp_horvath_betas_20211104.output.csv" output/
ln -sf "$SOURCE_ABS/igp_quality_control_20230222.Rmd" script/

echo "  ✓ Core analysis files linked"

echo ""
echo "Step 3: Preparing IDAT file symlinks"
echo ""

DOWNLOAD_IDAT_DIR="downloads/idat"
IDAT_TARGET_DIR="data/idat"

if [ -d "$DOWNLOAD_IDAT_DIR" ]; then
    IDAT_SOURCE_ABS=$(cd "$DOWNLOAD_IDAT_DIR" && pwd)
    mkdir -p "$IDAT_TARGET_DIR"

    find "$IDAT_TARGET_DIR" -maxdepth 1 -type l -exec rm -f {} \;
    find data -maxdepth 1 -type l \( -name "*.idat.gz" -o -name "*.idat" \) -exec rm -f {} \;

    idat_count=$(find "$IDAT_SOURCE_ABS" -maxdepth 1 -type f -name "*.idat.gz" 2>/dev/null | wc -l | tr -d ' ')
    echo "  Found $idat_count IDAT archives"

    if [ "$idat_count" -gt 0 ]; then
        while IFS= read -r idat_path; do
            base_name=$(basename "$idat_path")
            ln -sf "$IDAT_SOURCE_ABS/$base_name" "$IDAT_TARGET_DIR/$base_name"

            trimmed_name=$(echo "$base_name" | sed 's/^GSM[0-9]*_//')
            if [[ "$trimmed_name" != "$base_name" ]]; then
                ln -sf "$IDAT_SOURCE_ABS/$base_name" "data/${trimmed_name}"

                trimmed_no_gz="${trimmed_name%.gz}"
                if [[ "$trimmed_no_gz" != "$trimmed_name" ]]; then
                    ln -sf "$IDAT_SOURCE_ABS/$base_name" "data/${trimmed_no_gz}"
                fi
            fi
        done < <(find "$IDAT_SOURCE_ABS" -maxdepth 1 -type f -name "*.idat.gz")
        echo "  ✓ IDAT symlinks refreshed"
    else
        echo "  ⚠ No IDAT .gz files found. Run ./download.sh if you still need them."
    fi
else
    echo "  ⚠ $DOWNLOAD_IDAT_DIR not found. Run ./download.sh to fetch IDATs before linking."
fi

echo ""
echo "Verification"
echo "------------"
for file in \
    "data/cMulligan_SampleSheet160.csv" \
    "supp_data/cMulligan_SampleManifest160.csv" \
    "output/igp_horvath_betas_20211104.csv" \
    "script/igp_quality_control_20230222.Rmd"; do
    if [ -L "$file" ]; then
        target=$(readlink "$file")
        if [ -f "$file" ]; then
            echo "  ✓ $file -> $target"
        else
            echo "  ✗ $file -> $target (missing target)"
        fi
    elif [ -f "$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file (missing)"
    fi
done

echo ""
echo "Setup complete."
