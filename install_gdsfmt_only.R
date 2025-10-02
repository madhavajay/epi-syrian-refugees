#!/usr/bin/env Rscript

cat("=== manual gdsfmt install ===\n")

options(
  repos = c(CRAN = "https://cloud.r-project.org"),
  timeout = 300,
  Ncpus = max(1L, parallel::detectCores(logical = TRUE) - 1L)
)

message("-> Ensuring BiocManager availability")
if (!requireNamespace("BiocManager", quietly = TRUE)) {
  install.packages("BiocManager", dependencies = FALSE)
}

message("-> Installing gdsfmt from Bioconductor")
BiocManager::install("gdsfmt", ask = FALSE, update = FALSE)

message("-> Verifying gdsfmt load")
if (!requireNamespace("gdsfmt", quietly = TRUE)) {
  stop("gdsfmt still not loadable after install")
}

message("gdsfmt install script complete")
