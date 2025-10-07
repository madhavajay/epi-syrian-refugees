# Epigenetic Violence Analysis - Docker Image
# Multi-stage build for optimal caching and faster rebuilds
# Linux x86_64 R environment with all dependencies

# =============================================================================
# Stage 1: System dependencies (rarely changes)
# =============================================================================
FROM mambaorg/micromamba:1.5-jammy AS system-deps

USER root

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    curl \
    wget \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    libcairo2-dev \
    libxt-dev \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# Stage 2: Conda base environment (changes occasionally)
# =============================================================================
FROM system-deps AS conda-env

USER $MAMBA_USER
WORKDIR /workspace

# Copy only environment.yml for conda packages (from parent directory)
COPY --chown=$MAMBA_USER:$MAMBA_USER ../environment.yml ./

# Create conda environment from environment.yml
# This layer will be cached unless environment.yml changes
RUN micromamba create -n epigenetic-violence-analysis -f environment.yml -y && \
    micromamba clean --all --yes

ENV ENV_NAME=epigenetic-violence-analysis
ARG MAMBA_DOCKERFILE_ACTIVATE=1

# =============================================================================
# Stage 3: R package installation script (changes more frequently)
# =============================================================================
FROM conda-env AS r-packages

# Copy R package installation script (from parent directory)
COPY --chown=$MAMBA_USER:$MAMBA_USER ../install_packages.R ./

# Create cache directory for R packages (persists across builds with buildkit)
RUN mkdir -p /workspace/r_package_cache

# Install R packages within the conda environment
# Use --mount=type=cache to persist downloads across builds
RUN --mount=type=cache,target=/workspace/r_package_cache,uid=1000,gid=1000 \
    micromamba run -n ${ENV_NAME} Rscript install_packages.R

# =============================================================================
# Stage 4: Final runtime image
# =============================================================================
FROM conda-env AS final

# Copy installed R packages from previous stage
COPY --from=r-packages /opt/conda/envs/epigenetic-violence-analysis /opt/conda/envs/epigenetic-violence-analysis

# Copy scripts for reference (from parent directory)
COPY --chown=$MAMBA_USER:$MAMBA_USER ../install_packages.R ./
COPY --chown=$MAMBA_USER:$MAMBA_USER ../environment.yml ./

# Set environment activation in .bashrc
RUN echo "micromamba activate ${ENV_NAME}" >> ~/.bashrc

# Default to bash with environment activated
SHELL ["/usr/local/bin/_dockerfile_shell.sh"]
ENTRYPOINT ["/usr/local/bin/_entrypoint.sh"]
CMD ["/bin/bash"]

# Metadata
LABEL maintainer="Epigenetic Violence Analysis Team"
LABEL description="R environment for epigenetic violence analysis with all dependencies"
LABEL version="1.0"
LABEL stage="final"
