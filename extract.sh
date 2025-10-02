#!/bin/bash

set -e  # Exit on error

echo "========================================="
echo "Extracting data and setting up structure"
echo "========================================="
echo ""

cd data

echo "Step 1: Extracting ZIP files..."
echo ""

for f in *.zip; do
  if [ -f "$f" ]; then
    # Get filename without extension
    dirname="${f%.zip}"

    echo "Extracting: $f -> $dirname/"
    mkdir -p "$dirname"
    unzip -o "$f" -d "$dirname"
    echo "✓ Extraction complete"
    echo ""
  fi
done

echo "✓ All extractions complete"
echo ""

# Go back to project root
cd ..

echo "========================================="
echo "Step 2: Creating directory structure..."
echo "========================================="
echo ""

# Create required directories
mkdir -p data
mkdir -p supp_data
mkdir -p output
mkdir -p script

echo "✓ Created directories: data/, supp_data/, output/, script/"
echo ""

echo "========================================="
echo "Step 3: Setting up symlinks..."
echo "========================================="
echo ""

# Source directory with all the files
SOURCE_DIR="data/22183534"

# Symlink metadata files to supp_data/
echo "Linking metadata files to supp_data/..."
ln -sf "../${SOURCE_DIR}/cMulligan_SampleManifest160.csv" supp_data/
ln -sf "../${SOURCE_DIR}/IGP_SwabType.csv" supp_data/
ln -sf "../${SOURCE_DIR}/igp_ages.csv" supp_data/
ln -sf "../${SOURCE_DIR}/datMiniAnnotation3.csv" supp_data/
ln -sf "../${SOURCE_DIR}/IGP_Epi_Metadata20220330.csv" supp_data/
ln -sf "../${SOURCE_DIR}/all_samples_log_compiled_20220106.csv" supp_data/
ln -sf "../${SOURCE_DIR}/igp_relatedness_coded_20220105.csv" supp_data/
ln -sf "../${SOURCE_DIR}/infinium-methylationepic-v-1-0-b5-manifest-file.csv" supp_data/
echo "✓ Linked 8 metadata files"

# Symlink sample sheet to data/
echo "Linking sample sheet to data/..."
ln -sf "${SOURCE_DIR}/cMulligan_SampleSheet160.csv" data/
echo "✓ Linked cMulligan_SampleSheet160.csv"

# Symlink pre-calculated Horvath files to output/
echo "Linking Horvath files to output/..."
ln -sf "../${SOURCE_DIR}/igp_horvath_betas_20211104.csv" output/
ln -sf "../${SOURCE_DIR}/igp_horvath_samplesheet_20211104.csv" output/
ln -sf "../${SOURCE_DIR}/igp_horvath_betas_20211104.output.csv" output/
echo "✓ Linked 3 Horvath files"

# Symlink the analysis script to script/
echo "Linking analysis script to script/..."
ln -sf "../${SOURCE_DIR}/igp_quality_control_20230222.Rmd" script/
echo "✓ Linked igp_quality_control_20230222.Rmd"

# Symlink R project file to root
echo "Linking R project file to root..."
ln -sf "${SOURCE_DIR}/igp.Rproj" igp.Rproj
echo "✓ Linked igp.Rproj"

echo ""
echo "========================================="
echo "Step 4: Checking IDAT files..."
echo "========================================="
echo ""

# Check IDAT files and symlink if needed
if [ -d "data/idat" ]; then
  idat_count=$(find data/idat -name "*.idat.gz" 2>/dev/null | wc -l | tr -d ' ')
  echo "Found $idat_count IDAT files in data/idat/"

  if [ $idat_count -gt 0 ]; then
    echo "Linking IDAT files to data/..."
    if [ -L "data/*.idat.gz" ]; then
      rm -f "data/*.idat.gz"
    fi
    while IFS= read -r idat_path; do
      base_name=$(basename "$idat_path")
      ln -sf "idat/${base_name}" "data/${base_name}"

      trimmed_name=$(echo "$base_name" | sed 's/^GSM[0-9]*_//')
      if [[ "$trimmed_name" != "$base_name" ]]; then
        ln -sf "idat/${base_name}" "data/${trimmed_name}"
      fi
    done < <(find data/idat -maxdepth 1 -type f -name "*.idat.gz")
    echo "✓ Linked IDAT files"
  else
    echo "⚠ No IDAT files found - run ./download.sh to download them"
  fi
else
  echo "⚠ data/idat/ directory not found - run ./download.sh to download IDAT files"
fi

echo ""
echo "========================================="
echo "Setup complete!"
echo "========================================="
echo ""

echo "Directory structure:"
echo "  data/           - IDAT files + sample sheet"
echo "  supp_data/      - Metadata CSV files"
echo "  output/         - Pre-calculated Horvath files + analysis outputs"
echo "  script/         - R analysis scripts"
echo ""

# Verify symlinks
echo "Verifying critical files:"
for file in "data/cMulligan_SampleSheet160.csv" "supp_data/cMulligan_SampleManifest160.csv" "output/igp_horvath_betas_20211104.csv" "script/igp_quality_control_20230222.Rmd"; do
  if [ -L "$file" ]; then
    target=$(readlink "$file")
    if [ -f "$file" ]; then
      echo "  ✓ $file -> $target"
    else
      echo "  ✗ $file -> $target (broken link)"
    fi
  elif [ -f "$file" ]; then
    echo "  ✓ $file (regular file)"
  else
    echo "  ✗ $file (missing)"
  fi
done

echo ""
echo "Next steps:"
echo "  1. Setup R environment: ./setup_environment.sh"
echo "  2. Activate environment: source activate_env.sh"
