#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

mkdir -p "${REPO_ROOT}/logs"
ts="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${REPO_ROOT}/logs/install_gdsfmt_${ts}.log"

exec >>"${LOG_FILE}" 2>&1
echo "[install_gdsfmt.sh] logging to ${LOG_FILE}" >&2

ENV_DIR="${REPO_ROOT}/envs/epigenetic-violence-analysis"
RSCRIPT="${ENV_DIR}/bin/Rscript"

if [[ ! -x "${RSCRIPT}" ]]; then
    echo "❌ Rscript not found at ${RSCRIPT}. Run ./setup_environment.sh first." >&2
    exit 1
fi

ENV_DIR_ABS="$(cd "${ENV_DIR}" && pwd)"
PATCH_HEADER="${REPO_ROOT}/tools/char_traits_patch.h"

if [[ ! -f "${PATCH_HEADER}" ]]; then
    echo "❌ Compatibility header missing at ${PATCH_HEADER}." >&2
    exit 1
fi

if command -v xcrun >/dev/null 2>&1; then
    export SDKROOT="$(xcrun --sdk macosx --show-sdk-path 2>/dev/null)"
fi

for var in PKG_CPPFLAGS CPPFLAGS; do
    current="${!var-}"
    define="-DR_NO_REMAP"
    case " ${current} " in
        *"${define}"*) : ;;
        *) export ${var}="${define} ${current}" ;;
    esac
done

PATCH_VARS=(
    CXXFLAGS PKG_CXXFLAGS
    CXX11FLAGS PKG_CXX11FLAGS
    CXX14FLAGS PKG_CXX14FLAGS
    CXX17FLAGS PKG_CXX17FLAGS
    CXX20FLAGS PKG_CXX20FLAGS
)

for var in "${PATCH_VARS[@]}"; do
    current="${!var-}"
    inject="-DR_NO_REMAP -include ${PATCH_HEADER}"
    case " ${current} " in
        *"-include ${PATCH_HEADER}"*) : ;;
        *) export ${var}="${inject} ${current}" ;;
    esac
done

export PATH="${ENV_DIR_ABS}/bin:${PATH}"
export TMPDIR="${ENV_DIR_ABS}/tmp"
mkdir -p "${TMPDIR}"

ensure_toolchain() {
    if [[ -x "${ENV_DIR_ABS}/bin/x86_64-apple-darwin13.4.0-gfortran" ]]; then
        return 0
    fi

    if ! command -v micromamba >/dev/null 2>&1; then
        echo "⚠ micromamba not found; cannot auto-install Fortran toolchain." >&2
        return 1
    fi

    echo "[install_gdsfmt.sh] Installing Fortran/C build prerequisites via micromamba" >&2
    if [[ "$(uname -m)" == "arm64" ]]; then
        export CONDA_SUBDIR=osx-64
    fi

    micromamba install -y -p "${ENV_DIR_ABS}" \
        compilers gfortran libgfortran libuuid zlib bzip2 xz lz4 || true
    hash -r

    if [[ ! -x "${ENV_DIR_ABS}/bin/x86_64-apple-darwin13.4.0-gfortran" ]]; then
        echo "❌ gfortran not available in ${ENV_DIR_ABS}/bin." >&2
        return 1
    fi

    return 0
}

if ! ensure_toolchain; then
    echo "❌ Unable to prepare toolchain required for gdsfmt build." >&2
    exit 1
fi

INSTALLER="${REPO_ROOT}/install_gdsfmt_only.R"
if [[ ! -f "${INSTALLER}" ]]; then
    echo "❌ Installer script missing at ${INSTALLER}." >&2
    exit 1
fi

ARCH_CMD=(arch -x86_64 /bin/bash -lc)
RUN_CMD="'"${RSCRIPT}"' '"${INSTALLER}"'"

"${ARCH_CMD[@]}" "${RUN_CMD}"
