#!/bin/bash

# Create a test sample sheet with 4 samples for quick testing

echo "Creating test sample sheet..."

# Get header and first 4 data rows from original sample sheet
head -1 data/22183534/cMulligan_SampleSheet160.csv > data/cMulligan_SampleSheet_test.csv
tail -n +2 data/22183534/cMulligan_SampleSheet160.csv | head -4 >> data/cMulligan_SampleSheet_test.csv

# Normalize line endings to avoid stray carriage returns
perl -pi -e 's/\r//g' data/cMulligan_SampleSheet_test.csv

sample_count=$(tail -n +2 data/cMulligan_SampleSheet_test.csv | wc -l | tr -d ' ')

echo "✓ Created data/cMulligan_SampleSheet_test.csv"
echo "  Contains: $sample_count samples (header + 4 samples)"
echo ""

# Show what samples are included
echo "Test samples:"
tail -n +2 data/cMulligan_SampleSheet_test.csv | awk -F',' '{print "  - " $1}'
echo ""

# Check if corresponding IDAT files exist
echo "Checking IDAT files for test samples..."
missing=0
while IFS=',' read -r sample_name rest; do
    # Get the id field (last column)
    id=$(echo "$rest" | awk -F',' '{print $NF}')

    grn_file="data/${id}_Grn.idat.gz"
    red_file="data/${id}_Red.idat.gz"

    if [ -f "$grn_file" ] && [ -f "$red_file" ]; then
        echo "  ✓ $id (Green + Red)"
    else
        echo "  ✗ $id (missing IDAT files)"
        missing=$((missing + 1))
    fi
done < <(tail -n +2 data/cMulligan_SampleSheet_test.csv)

echo ""
if [ $missing -gt 0 ]; then
    echo "⚠ Warning: $missing test samples missing IDAT files"
    echo "  Download IDAT files with: ./download.sh"
else
    echo "✓ All test sample IDAT files present"
fi
