#!/usr/bin/env bash
set -euo pipefail

# Bootstrap a working build/check environment for this project, even on fresh machines.
# - Creates/uses .venv
# - Installs/updates pip, setuptools, wheel
# - Ensures 'build' and 'twine' (via venv; falls back to pipx when needed)
# - Runs: python -m build && twine check dist/*

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

log() { printf '[%s] %s\n' "$(date +'%H:%M:%S')" "$*"; }
warn() { printf '[%s] WARN: %s\n' "$(date +'%H:%M:%S')" "$*" >&2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

ensure_python3() {
  if have python3; then return 0; fi
  warn "python3 not found in PATH. Attempting to install via Homebrew..."
  if have brew; then
    brew install python || die "Failed to install python via Homebrew. Install Python 3 manually."
  else
    die "python3 is required but not found. Please install Python 3 (3.10+) and re-run."
  fi
}

ensure_pipx() {
  if have pipx; then return 0; fi
  if have brew; then
    log "Installing pipx via Homebrew..."
    brew install pipx || warn "Homebrew pipx install failed; trying pip --user"
  fi
  if ! have pipx; then
    if have python3; then
      log "Installing pipx via pip --user..."
      python3 -m pip install --user pipx || warn "pipx user install failed"
    fi
  fi
  # Ensure ~/.local/bin on PATH for current shell
  export PATH="$HOME/.local/bin:$PATH"
  have pipx || warn "pipx still not found; will proceed without pipx fallback"
}

ensure_venv() {
  if [ ! -d "$PROJECT_ROOT/.venv" ]; then
    log "Creating virtual environment at .venv..."
    python3 -m venv "$PROJECT_ROOT/.venv" || die "Failed to create .venv"
  fi
}

venv_python() { echo "$PROJECT_ROOT/.venv/bin/python"; }
venv_pip() { echo "$PROJECT_ROOT/.venv/bin/pip"; }

ensure_core_tools_in_venv() {
  log "Upgrading pip/setuptools/wheel in .venv..."
  "$(venv_python)" -m pip install -U pip setuptools wheel || warn "pip/setuptools/wheel upgrade reported an issue; continuing"
}

ensure_package_in_venv() {
  local pkg="$1"
  if "$(venv_python)" -c "import $pkg" >/dev/null 2>&1; then
    return 0
  fi
  log "Installing $pkg in .venv..."
  if ! "$(venv_python)" -m pip install "$pkg"; then
    warn "Failed to install $pkg into .venv"
    return 1
  fi
}

run_build() {
  log "Building sdist and wheel with python -m build ..."
  if "$(venv_python)" -m build "$PROJECT_ROOT"; then
    return 0
  fi
  warn "python -m build failed in .venv"
  if have pipx; then
    log "Falling back to pipx run build ..."
    if pipx run build "$PROJECT_ROOT"; then
      return 0
    fi
    warn "pipx run build also failed"
  fi
  die "Build failed. See logs above."
}

run_twine_check() {
  local pattern=("$PROJECT_ROOT/dist"/*)
  if [ ! -e "${pattern[0]}" ]; then
    die "No files in dist/. Did the build step succeed?"
  fi
  log "Checking artifacts with twine ..."
  if "$(venv_python)" -m twine check "$PROJECT_ROOT"/dist/*; then
    return 0
  fi
  warn "twine check via .venv failed or twine missing"
  if have pipx; then
    log "Falling back to pipx run twine check ..."
    if pipx run twine check "$PROJECT_ROOT"/dist/*; then
      return 0
    fi
    warn "pipx twine check also failed"
  fi
  die "twine check failed. See logs above."
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [--ensure-only] [--build-only] [--check-only]

Default (no flags): ensure env + build + twine check.

Flags:
  --ensure-only  Only ensure environment/tools (no build/check)
  --build-only   Only run build (skips ensure/check)
  --check-only   Only run twine check on dist/* (skips ensure/build)
EOF
}

main() {
  local ensure_only=0 build_only=0 check_only=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --ensure-only) ensure_only=1 ;;
      --build-only)  build_only=1 ;;
      --check-only)  check_only=1 ;;
      -h|--help) usage; exit 0 ;;
      *) usage; exit 1 ;;
    esac
    shift
  done

  if [ "$build_only" -eq 0 ] && [ "$check_only" -eq 0 ]; then
    # Ensure phase
    ensure_python3
    ensure_pipx || true
    ensure_venv
    ensure_core_tools_in_venv
    # Ensure build + twine in venv (best-effort); fall back to pipx later if needed
    ensure_package_in_venv build || true
    ensure_package_in_venv twine || true
    log "Environment ensured."
    if [ "$ensure_only" -eq 1 ]; then exit 0; fi
  fi

  if [ "$check_only" -eq 0 ]; then
    # Build phase
    run_build
  fi

  if [ "$build_only" -eq 0 ]; then
    # Check phase
    run_twine_check
  fi

  log "All done. Artifacts in: $PROJECT_ROOT/dist"
}

main "$@"


