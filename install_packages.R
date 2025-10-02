#!/usr/bin/env Rscript

cat("========================================\n")
cat("Installing R packages for Epigenetic Violence Analysis\n")
cat("========================================\n\n")

# Set CRAN mirror
options(repos = c(CRAN = "https://cloud.r-project.org/"))

# Install BiocManager if not present
if (!requireNamespace("BiocManager", quietly = TRUE)) {
  install.packages("BiocManager")
}

BiocManager::install(version = "3.16", ask = FALSE, update = FALSE)

cat("\n--- Installing CRAN packages ---\n")
cran_packages <- c(
  "broom",
  "data.table",
  "DiagrammeR",
  "doParallel",
  "dplyr",
  "DT",
  "emmeans",
  "factoextra",
  "forcats",
  "geepack",
  "ggdendro",
  "ggeffects",
  "ggforce",
  "ggplot2",
  "ggpubr",
  "gplots",
  "here",
  "Hmisc",
  "kableExtra",
  "lmtest",
  "magrittr",
  "MASS",
  "pander",
  "parallel",
  "PCAtools",
  "purrr",
  "rebus",
  "sandwich",
  "stringi",
  "stringr",
  "svd",
  "table1",
  "tidyr",
  "vegan",
  "xtable"
)

for (pkg in cran_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat(paste0("Installing ", pkg, "...\n"))
    install.packages(pkg, quiet = TRUE)
  } else {
    cat(paste0("✓ ", pkg, " already installed\n"))
  }
}

cat("\n--- Installing Bioconductor packages ---\n")
bioc_packages <- c(
  "minfi",
  "sesame",
  "sesameData",
  "meffil",
  "EpiDISH",
  "sva",
  "DNAmArray",
  "FDb.InfiniumMethylation.hg19",
  "IlluminaHumanMethylationEPICmanifest",
  "org.Hs.eg.db"
)

for (pkg in bioc_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat(paste0("Installing ", pkg, "...\n"))
    BiocManager::install(pkg, ask = FALSE, update = FALSE)
  } else {
    cat(paste0("✓ ", pkg, " already installed\n"))
  }
}

cat("\n--- Installing GitHub packages ---\n")

# Install ewastools from GitHub
if (!requireNamespace("ewastools", quietly = TRUE)) {
  cat("Installing ewastools from GitHub...\n")
  if (!requireNamespace("remotes", quietly = TRUE)) {
    install.packages("remotes")
  }
  remotes::install_github("hhhh5/ewastools")
} else {
  cat("✓ ewastools already installed\n")
}

cat("\n========================================\n")
cat("Package installation complete!\n")
cat("========================================\n\n")

# Print R version and loaded packages
cat("R version:\n")
print(R.version.string)

cat("\nChecking key packages:\n")
key_packages <- c("minfi", "sesame", "meffil", "ewastools", "here", "tidyverse")
for (pkg in key_packages) {
  if (requireNamespace(pkg, quietly = TRUE)) {
    cat(paste0("✓ ", pkg, "\n"))
  } else {
    cat(paste0("✗ ", pkg, " - INSTALLATION FAILED\n"))
  }
}
