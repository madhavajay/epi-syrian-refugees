#!/usr/bin/env Rscript

cat("=== meffil targeted install ===\n")

options(repos = c(CRAN = "https://cloud.r-project.org"))
options(timeout = 300, Ncpus = max(1L, parallel::detectCores() - 1L))

ensure_pkg <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg)
  }
}

ensure_pkg("BiocManager")
ensure_pkg("remotes")

message("-> Installing Bioconductor dependency 'gdsfmt'")
BiocManager::install("gdsfmt", ask = FALSE, update = FALSE)

message("-> Installing CRAN dependency 'Cairo'")
if (!requireNamespace("Cairo", quietly = TRUE)) {
  install.packages("Cairo")
}

message("-> Installing meffil from GitHub")
remotes::install_github("perishky/meffil", upgrade = "never")

message("meffil install script complete")
