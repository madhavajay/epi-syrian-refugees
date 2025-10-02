#!/bin/bash

set -e

ENV_NAME="epigenetic-violence-analysis"
ENV_DIR="./envs/${ENV_NAME}"
RSCRIPT="${ENV_DIR}/bin/Rscript"

if [ ! -f "$RSCRIPT" ]; then
    echo "✗ Environment not found: $ENV_DIR"
    exit 1
fi

echo "========================================="
echo "Verifying R Package Installation"
echo "========================================="
echo ""

# Run R verification script
"$RSCRIPT" - <<'EOF'
# Package lists from install_packages.R
cran_packages <- c(
  "jsonlite", "data.table", "Rcpp", "broom", "dplyr", "DT", "forcats",
  "ggplot2", "here", "magrittr", "purrr", "stringr", "tidyr",
  "GGally", "ggalluvial", "ggdendro", "ggdist", "ggeffects", "ggforce", "gghalves",
  "ggrepel", "ggVennDiagram", "gplots", "gtools", "scales", "viridis", "patchwork",
  "bacon", "doParallel", "emmeans", "factoextra", "geepack",
  "Hmisc", "jtools", "lmtest", "MASS", "na.tools", "pander",
  "parallel", "PCAtools", "prediction", "qqman", "rebus",
  "resample", "rlist", "sandwich", "stringi", "svd", "table1",
  "vegan", "xtable", "CGPfunctions", "DiagrammeR"
)

bioc_packages <- c(
  "minfi", "sesame", "sesameData", "EpiDISH", "sva",
  "FDb.InfiniumMethylation.hg19",
  "IlluminaHumanMethylationEPICmanifest",
  "IlluminaHumanMethylationEPICanno.ilm10b4.hg19",
  "missMethyl", "org.Hs.eg.db"
)

github_packages <- c("ewastools", "meffil", "methylCIPHER", "ClusterBootstrap")

failed <- c()
passed <- 0

cat("Checking CRAN packages:\n")
for (pkg in cran_packages) {
  if (requireNamespace(pkg, quietly = TRUE)) {
    cat(paste0("  ✓ ", pkg, "\n"))
    passed <- passed + 1
  } else {
    cat(paste0("  ✗ ", pkg, "\n"))
    failed <- c(failed, pkg)
  }
}

cat("\nChecking Bioconductor packages:\n")
for (pkg in bioc_packages) {
  if (requireNamespace(pkg, quietly = TRUE)) {
    cat(paste0("  ✓ ", pkg, "\n"))
    passed <- passed + 1
  } else {
    cat(paste0("  ✗ ", pkg, "\n"))
    failed <- c(failed, pkg)
  }
}

cat("\nChecking GitHub packages:\n")
for (pkg in github_packages) {
  if (requireNamespace(pkg, quietly = TRUE)) {
    cat(paste0("  ✓ ", pkg, "\n"))
    passed <- passed + 1
  } else {
    cat(paste0("  ✗ ", pkg, " (optional)\n"))
    failed <- c(failed, pkg)
  }
}

total <- length(cran_packages) + length(bioc_packages) + length(github_packages)
cat("\n========================================\n")
cat(paste0("Results: ", passed, "/", total, " packages installed\n"))
cat("========================================\n\n")

if (length(failed) > 0) {
  cat("Failed packages:\n")
  for (pkg in failed) {
    cat(paste0("  - ", pkg, "\n"))
  }
  cat("\n")
  quit(status = 1)
} else {
  cat("✓ All packages successfully installed!\n\n")
  quit(status = 0)
}
EOF

exit_code=$?

if [ $exit_code -eq 0 ]; then
    echo "✓ Verification PASSED"
    exit 0
else
    echo "✗ Verification FAILED - some packages missing"
    exit 1
fi
