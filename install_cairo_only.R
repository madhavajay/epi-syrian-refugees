#!/usr/bin/env Rscript

cat("=== manual Cairo install ===\n")

options(
  repos = c(CRAN = "https://cloud.r-project.org"),
  timeout = 300,
  Ncpus = max(1L, parallel::detectCores(logical = TRUE) - 1L)
)

message("-> Ensuring remotes package for diagnostics")
if (!requireNamespace("remotes", quietly = TRUE)) {
  install.packages("remotes", dependencies = FALSE)
}

message("-> Checking system cairo availability via pkg-config")
pkg_config <- Sys.getenv("PKG_CONFIG", unset = "pkg-config")
if (!nzchar(Sys.which(pkg_config))) {
  stop("pkg-config not found on PATH; aborting Cairo install")
}

pc_result <- try(system2(pkg_config, c("--cflags", "cairo"), stdout = TRUE, stderr = TRUE), silent = TRUE)
if (inherits(pc_result, "try-error")) {
  stop("pkg-config failed to report cairo cflags. Output: ", conditionMessage(attr(pc_result, "condition")))
}
message("   cairo cflags: ", paste(pc_result, collapse = " "))

message("-> Installing Cairo from CRAN (source)")
install.packages("Cairo", type = "source", INSTALL_opts = "--no-multiarch")

message("-> Verifying Cairo load")
if (!requireNamespace("Cairo", quietly = TRUE)) {
  stop("Cairo still not loadable after install")
}

message("Cairo install script complete")
