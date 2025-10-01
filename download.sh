#!/bin/bash

mkdir -p data
cd data

# Add browser-like headers to bypass restrictions
USER_AGENT="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

download_file() {
  local url="$1"
  local referer="$2"
  local description="$3"
  local article_id=$(echo "$url" | sed -n 's/.*articles\/\([0-9]*\).*/\1/p')
  local filename="${article_id}.zip"

  echo "Checking: $description"
  echo "Source: $referer"
  echo "Target file: $filename"

  # Check if file exists and verify it
  if [ -f "$filename" ]; then
    local local_size=$(stat -f%z "$filename" 2>/dev/null || stat -c%s "$filename" 2>/dev/null)
    echo "File exists (Size: $local_size bytes)"

    # Verify zip integrity
    if unzip -t "$filename" >/dev/null 2>&1; then
      echo "✓ ZIP verification passed, skipping download"
      echo ""
      return 0
    else
      echo "✗ ZIP verification failed, file is corrupted"
      echo "  Deleting and re-downloading..."
      rm -f "$filename"
    fi
  fi

  # Download
  echo "Downloading..."
  curl -L -A "$USER_AGENT" \
    -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8" \
    -H "Accept-Language: en-US,en;q=0.5" \
    -H "Referer: $referer" \
    -o "$filename" "$url"

  if [ $? -eq 0 ]; then
    local final_size=$(stat -f%z "$filename" 2>/dev/null || stat -c%s "$filename" 2>/dev/null)
    echo "✓ Download complete (Size: $final_size bytes)"

    # Verify downloaded zip
    echo "Verifying ZIP integrity..."
    if unzip -t "$filename" >/dev/null 2>&1; then
      echo "✓ ZIP verification passed"
    else
      echo "✗ ZIP verification failed - file may be corrupted"
      echo "  Please delete data/$filename and run this script again"
    fi
  else
    echo "✗ Download failed"
  fi
  echo ""
}

# Methylation data quality control
# https://figshare.com/s/8c0ea5088435801782d2
download_file \
  "https://figshare.com/ndownloader/articles/22183534?private_link=8c0ea5088435801782d2" \
  "https://figshare.com/s/8c0ea5088435801782d2" \
  "Methylation data quality control"

# Epigenome-wide analysis
# https://figshare.com/s/e62913140c6128fef796
download_file \
  "https://figshare.com/ndownloader/articles/22183384?private_link=e62913140c6128fef796" \
  "https://figshare.com/s/e62913140c6128fef796" \
  "Epigenome-wide analysis"

# Epigenetic age quality control
# https://figshare.com/s/804208ad194319ff20ff
download_file \
  "https://figshare.com/ndownloader/articles/23498670?private_link=804208ad194319ff20ff" \
  "https://figshare.com/s/804208ad194319ff20ff" \
  "Epigenetic age quality control"

# Epigenetic age acceleration analysis
# https://figshare.com/s/48782e37381065963581
download_file \
  "https://figshare.com/ndownloader/articles/23498658?private_link=48782e37381065963581" \
  "https://figshare.com/s/48782e37381065963581" \
  "Epigenetic age acceleration analysis"

echo "All downloads complete"
