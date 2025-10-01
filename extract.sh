#!/bin/bash

cd data

echo "Extracting all ZIP files in data directory..."
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

echo "All extractions complete"
