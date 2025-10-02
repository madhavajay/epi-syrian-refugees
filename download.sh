#!/bin/bash

# Parse command line arguments
SKIP_VERIFY=false
if [[ "$1" == "--skip-verify" ]]; then
  SKIP_VERIFY=true
  echo "Running with --skip-verify: skipping file verification"
  echo ""
fi

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

    if [ "$SKIP_VERIFY" = true ]; then
      echo "✓ Skipping download (verification disabled)"
      echo ""
      return 0
    fi

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

    if [ "$SKIP_VERIFY" = false ]; then
      # Verify downloaded zip
      echo "Verifying ZIP integrity..."
      if unzip -t "$filename" >/dev/null 2>&1; then
        echo "✓ ZIP verification passed"
      else
        echo "✗ ZIP verification failed - file may be corrupted"
        echo "  Please delete data/$filename and run this script again"
      fi
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

echo "All figshare downloads complete"
echo ""

# Download IDAT files from GEO
echo "========================================="
echo "Downloading IDAT files from GEO GSE226085"
echo "========================================="
echo ""

# Create idat directory
cd ..
mkdir -p data/idat
mkdir -p data/.cache
cd data/idat

# Function to download IDAT file
download_idat() {
  local url="$1"
  local filename="$2"

  # Check if file exists and verify it
  if [ -f "$filename" ]; then
    if [ "$SKIP_VERIFY" = true ]; then
      echo "✓ $filename already exists, skipping (verification disabled)"
      return 0
    fi

    # Verify gzip integrity
    if gzip -t "$filename" 2>/dev/null; then
      echo "✓ $filename already exists and is valid, skipping"
      return 0
    else
      echo "✗ $filename exists but is corrupted, re-downloading"
      rm -f "$filename"
    fi
  fi

  echo "Downloading: $filename"
  curl -L -A "$USER_AGENT" \
    -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8" \
    -H "Accept-Language: en-US,en;q=0.5" \
    -o "$filename" "$url"

  if [ $? -eq 0 ]; then
    local file_size=$(stat -f%z "$filename" 2>/dev/null || stat -c%s "$filename" 2>/dev/null)

    if [ "$SKIP_VERIFY" = false ]; then
      # Verify downloaded gzip
      if gzip -t "$filename" 2>/dev/null; then
        echo "✓ Download complete and verified ($file_size bytes)"
      else
        echo "✗ Download failed verification - file may be corrupted"
        echo "  Please delete data/idat/$filename and run this script again"
      fi
    else
      echo "✓ Download complete ($file_size bytes, verification skipped)"
    fi
  else
    echo "✗ Download failed"
  fi
}

# Get list of GSM accessions from series page
series_cache="../.cache/GSE226085.html"
if [ -f "$series_cache" ]; then
  echo "Using cached sample list from GSE226085..."
  series_page=$(cat "$series_cache")
else
  echo "Fetching sample list from GSE226085..."
  http_code=$(curl -s -L -A "$USER_AGENT" -w "%{http_code}" -o "$series_cache.tmp" "https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE226085")

  if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
    mv "$series_cache.tmp" "$series_cache"
    series_page=$(cat "$series_cache")
    echo "✓ Cached series page"
  else
    echo "✗ Failed to fetch series page (HTTP $http_code)"
    rm -f "$series_cache.tmp"
    exit 1
  fi
fi

# Extract GSM accession numbers
gsm_accessions=$(echo "$series_page" | grep -o 'GSM[0-9]\{7\}' | sort -u)

gsm_count=$(echo "$gsm_accessions" | wc -l | tr -d ' ')
echo "Found $gsm_count samples"
echo ""

# Counter for progress
current=0

# For each GSM accession, get the IDAT files
for gsm in $gsm_accessions; do
  current=$((current + 1))
  echo "[$current/$gsm_count] Processing $gsm..."

  # Check cache for GSM page
  gsm_cache="../.cache/${gsm}.html"
  if [ -f "$gsm_cache" ]; then
    gsm_page=$(cat "$gsm_cache")
  else
    # Fetch the GSM page
    http_code=$(curl -s -L -A "$USER_AGENT" -w "%{http_code}" -o "$gsm_cache.tmp" "https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=$gsm")

    if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
      mv "$gsm_cache.tmp" "$gsm_cache"
      gsm_page=$(cat "$gsm_cache")
    else
      echo "  ✗ Failed to fetch $gsm page (HTTP $http_code), skipping"
      rm -f "$gsm_cache.tmp"
      echo ""
      continue
    fi
  fi

  # Extract IDAT file URLs (http links)
  # Pattern matches both .idat.gz and %2Eidat%2Egz (URL-encoded version)
  idat_urls=$(echo "$gsm_page" | grep -o '/geo/download/?[^"]*idat[^"]*' | sed 's/&amp;/\&/g')

  if [ -z "$idat_urls" ]; then
    echo "  ⚠ No IDAT files found for $gsm"
  else
    # Download each IDAT file for this sample
    for url_path in $idat_urls; do
      full_url="https://www.ncbi.nlm.nih.gov${url_path}"
      filename=$(echo "$url_path" | grep -o 'file=.*' | sed 's/file=//' | sed 's/%5F/_/g' | sed 's/%2E/./g' | sed 's/%2F/\//g')

      download_idat "$full_url" "$filename"
    done
  fi

  echo ""
done

echo "========================================="
echo "All IDAT downloads complete"
echo "========================================="
