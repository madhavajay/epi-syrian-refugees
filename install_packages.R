#!/usr/bin/env Rscript

cat("========================================\n")
cat("Installing R packages for Epigenetic Violence Analysis\n")
cat("========================================\n\n")

# Set CRAN mirror and increase timeout for slow networks
options(repos = c(CRAN = "https://cloud.r-project.org/"))
options(timeout = 300)  # 5 minutes instead of 60 seconds

# Parallel compilation - use all CPU cores
num_cores <- parallel::detectCores()
cat(paste0("Detected ", num_cores, " CPU cores - enabling parallel compilation\n"))
Sys.setenv(MAKEFLAGS = paste0("-j", num_cores))
options(Ncpus = num_cores)

# Keep downloaded packages in persistent cache (don't delete after install)
download_cache <- normalizePath("./r_package_cache", mustWork = FALSE)
dir.create(download_cache, showWarnings = FALSE, recursive = TRUE)
options(keep.source.pkgs = TRUE)
Sys.setenv(R_INSTALL_STAGED = "false")  # Disable staged install to keep sources

# Ensure libc++ still sees legacy char_traits specialisations needed by gdsfmt (macOS only)
is_macos <- .Platform$OS.type == "unix" && Sys.info()["sysname"] == "Darwin"
patch_header_path <- file.path("tools", "char_traits_patch.h")
has_patch_header <- file.exists(patch_header_path)

append_flag <- function(var, flag) {
  current <- Sys.getenv(var)
  if (!nzchar(current)) {
    do.call(Sys.setenv, setNames(list(flag), var))
  } else if (!grepl(flag, current, fixed = TRUE)) {
    do.call(Sys.setenv, setNames(list(paste(flag, current)), var))
  }
}

# Apply macOS-specific compilation fixes (char_traits patch for gdsfmt compatibility)
if (is_macos && has_patch_header) {
  patch_header <- normalizePath(patch_header_path, mustWork = TRUE)

  # Ensure C/C++ compilation uses original R entry points (avoids Rf_* remapping)
  for (var in c("PKG_CPPFLAGS", "CPPFLAGS", "CFLAGS", "PKG_CFLAGS")) {
    append_flag(var, "-DR_NO_REMAP")
  }

  # Inject compatibility header for C++ compilation units only
  for (var in c(
    "CXXFLAGS", "PKG_CXXFLAGS",
    "CXX11FLAGS", "PKG_CXX11FLAGS",
    "CXX14FLAGS", "PKG_CXX14FLAGS",
    "CXX17FLAGS", "PKG_CXX17FLAGS",
    "CXX20FLAGS", "PKG_CXX20FLAGS"
  )) {
    append_flag(var, "-DR_NO_REMAP")
    append_flag(var, paste("-include", patch_header))
  }
  cat("✓ Applied char_traits compatibility patch for macOS\n")
} else {
  cat("✓ Linux detected - using standard R compilation flags\n")
}

# Prefer binary packages to avoid slow compilation
# Note: conda-forge R builds don't support pkgType="both" (CRAN-only feature)
# Instead, we rely on conda-forge's binary packages already installed
# and CRAN's automatic binary selection for additional packages
if (.Platform$OS.type == "unix" && Sys.info()["sysname"] == "Darwin") {
  # macOS: Let R auto-detect available binaries
  cat("macOS detected: Using default package type (auto-detects binaries)\n\n")
} else {
  # Linux: binaries often not available, will compile as needed
  cat("Linux detected: Will compile from source as needed\n\n")
}

# Install BiocManager if not present
if (!requireNamespace("BiocManager", quietly = TRUE)) {
  install.packages("BiocManager")
}

BiocManager::install(version = "3.20", ask = FALSE, update = FALSE)

cat("\n--- Installing CRAN packages (ALL BATCHES) ---\n")
cran_packages <- c(
  # Core
  "jsonlite", "data.table", "Rcpp", "broom", "dplyr", "DT", "forcats",
  "ggplot2", "here", "magrittr", "purrr", "stringr", "tidyr",
  # Missing dependencies first (needed by other packages)
  # Note: igraph, Cairo, nloptr, XML are installed via conda to avoid compilation issues on Linux
  # Note: kableExtra is installed from GitHub later (see GitHub packages section)
  # On macOS these compile fine from CRAN, but we use conda for cross-platform consistency
  "mvtnorm", "multcomp", "lme4", "DNAcopy", "pls",
  "flashClust", "leaps", "car", "ggpubr", "BayesFactor", "DescTools",
  "partykit",
  # Visualization
  "GGally", "ggalluvial", "ggdendro", "ggdist", "ggeffects", "ggforce", "gghalves",
  "ggrepel", "ggVennDiagram", "gplots", "gtools", "scales", "viridis", "patchwork",
  # Stats & analysis
  "doParallel", "emmeans", "factoextra", "geepack",
  "Hmisc", "jtools", "lmtest", "MASS", "na.tools", "pander",
  "parallel", "prediction", "qqman", "rebus",
  "resample", "rlist", "sandwich", "stringi", "svd", "table1",
  "vegan", "xtable",
  # Complex packages (depend on above)
  "FactoMineR", "CGPfunctions", "DiagrammeR"
)

for (pkg in cran_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat(paste0("Installing ", pkg, "...\n"))
    # Don't suppress output - shows whether binary or source is used
    # Use destdir to keep downloads in persistent cache
    install.packages(pkg, destdir = download_cache)
  } else {
    cat(paste0("✓ ", pkg, " already installed\n"))
  }
}

cat("\n--- Installing Bioconductor packages ---\n")
bioc_packages <- c(
  "gdsfmt", "DNAcopy",  # Dependencies for meffil
  "bacon", "PCAtools",
  "minfi", "sesame", "sesameData", "EpiDISH", "sva",
  "DNAmArray",
  "FDb.InfiniumMethylation.hg19",
  "IlluminaHumanMethylationEPICmanifest",
  "IlluminaHumanMethylationEPICanno.ilm10b4.hg19",
  "missMethyl", "org.Hs.eg.db"
)

for (pkg in bioc_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat(paste0("Installing ", pkg, "...\n"))
    BiocManager::install(pkg, ask = FALSE, update = FALSE, destdir = download_cache)
  } else {
    cat(paste0("✓ ", pkg, " already installed\n"))
  }
}

# Fallback for DNAmArray (archived on Bioconductor as of 3.20)
if (!requireNamespace("DNAmArray", quietly = TRUE)) {
  cat("Installing DNAmArray from GitHub (Bioconductor release unavailable)...\n")
  remotes::install_github("molepi/DNAmArray", upgrade = "never")
}

cat("\n--- Installing GitHub packages ---\n")

# Ensure remotes is installed
if (!requireNamespace("remotes", quietly = TRUE)) {
  cat("Installing remotes...\n")
  install.packages("remotes", destdir = download_cache)
}

# Fallback for kableExtra (not yet published for current R release)
if (!requireNamespace("kableExtra", quietly = TRUE)) {
  cat("Installing kableExtra from GitHub (CRAN build unavailable)...\n")
  remotes::install_github("haozhu233/kableExtra")
}

# Install ewastools from GitHub
if (!requireNamespace("ewastools", quietly = TRUE)) {
  cat("Installing ewastools from GitHub...\n")
  remotes::install_github("hhhh5/ewastools")
} else {
  cat("✓ ewastools already installed\n")
}

# Install meffil from GitHub
if (!requireNamespace("meffil", quietly = TRUE)) {
  cat("Installing meffil from GitHub...\n")

  # First ensure SmartSVA is installed (XML should be from conda)
  if (!requireNamespace("SmartSVA", quietly = TRUE)) {
    cat("Installing SmartSVA dependency...\n")
    tryCatch({
      install.packages("SmartSVA", destdir = download_cache)
    }, error = function(e) {
      cat("⚠ SmartSVA installation failed:", e$message, "\n")
    })
  }

  # Now install meffil, telling it to upgrade dependencies but not XML (from conda)
  tryCatch({
    remotes::install_github("perishky/meffil", upgrade = "never")
  }, error = function(e) {
    cat("⚠ meffil installation failed:", e$message, "\n")
  })
} else {
  cat("✓ meffil already installed\n")
}

# Install methylCIPHER from GitHub
if (!requireNamespace("methylCIPHER", quietly = TRUE)) {
  cat("Installing methylCIPHER from GitHub...\n")
  tryCatch({
    remotes::install_github("MorganLevineLab/methylCIPHER")
  }, error = function(e) {
    cat("⚠ methylCIPHER installation failed:", e$message, "\n")
  })
} else {
  cat("✓ methylCIPHER already installed\n")
}

# Install ggmosaic (needs ggplot2 ≥ 4 support from GitHub)
if (!requireNamespace("ggmosaic", quietly = TRUE)) {
  cat("Installing ggmosaic from GitHub (ggplot2 >= 4 support)...\n")
  tryCatch({
    remotes::install_github("haleyjeppson/ggmosaic")
  }, error = function(e) {
    cat("⚠ ggmosaic installation failed (optional package)\n")
  })
} else {
  cat("✓ ggmosaic already installed\n")
}

# Install ClusterBootstrap from GitHub (optional)
if (!requireNamespace("ClusterBootstrap", quietly = TRUE)) {
  cat("Installing ClusterBootstrap from GitHub...\n")
  tryCatch({
    remotes::install_github("mathijsdeen/ClusterBootstrap")
  }, error = function(e) {
    cat("⚠ ClusterBootstrap installation failed (optional)\n")
  })
} else {
  cat("✓ ClusterBootstrap already installed\n")
}

cat("\n========================================\n")
cat("Package installation complete!\n")
cat("========================================\n\n")

# Print R version and loaded packages
cat("R version:\n")
print(R.version.string)

cat("\nChecking key packages:\n")
key_packages <- c("minfi", "sesame", "meffil", "ewastools", "methylCIPHER", "here", "tidyverse")
for (pkg in key_packages) {
  if (requireNamespace(pkg, quietly = TRUE)) {
    cat(paste0("✓ ", pkg, "\n"))
  } else {
    cat(paste0("✗ ", pkg, " - INSTALLATION FAILED (critical for analysis)\n"))
  }
}

cat("\nChecking optional packages:\n")
optional_packages <- c("GGally", "ggdist", "gghalves", "ClusterBootstrap", "bacon", "PCAtools")
for (pkg in optional_packages) {
  if (requireNamespace(pkg, quietly = TRUE)) {
    cat(paste0("✓ ", pkg, "\n"))
  } else {
    cat(paste0("⚠ ", pkg, " - not installed (optional)\n"))
  }
}
