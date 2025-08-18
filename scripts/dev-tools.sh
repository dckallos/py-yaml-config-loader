#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log() { printf '[%s] %s\n' "$(date +'%H:%M:%S')" "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

ensure_pipx() {
  if have pipx; then
    return 0
  fi
  if have brew; then
    log "Installing pipx via Homebrew..."
    brew install pipx
  elif have python3; then
    log "Installing pipx via pip..."
    python3 -m pip install --user pipx
  else
    die "Neither brew nor python3 found; cannot install pipx"
  fi
  export PATH="$HOME/.local/bin:$PATH"
  pipx ensurepath || true
}

ensure_tools_pipx() {
  ensure_pipx
  export PATH="$HOME/.local/bin:$PATH"
  local tools=(black ruff mypy twine build)
  for t in "${tools[@]}"; do
    if pipx list | grep -qE "package $t "; then
      log "Upgrading $t (pipx)..."
      pipx upgrade "$t" || true
    else
      log "Installing $t (pipx)..."
      pipx install "$t"
    fi
  done
}

ensure_venv() {
  if [ ! -d "$PROJECT_ROOT/.venv" ]; then
    log "Creating .venv..."
    python3 -m venv "$PROJECT_ROOT/.venv"
  fi
  # shellcheck disable=SC1091
  source "$PROJECT_ROOT/.venv/bin/activate"
  log "Upgrading pip in .venv..."
  python -m pip install -U pip
  log "Installing dev dependencies in .venv..."
  if ! python -m pip install -e "$PROJECT_ROOT[dev]"; then
    python -m pip install -e "$PROJECT_ROOT"
    python -m pip install pytest pytest-cov mypy black ruff build twine
  fi
}

run_tool() {
  local tool="$1"; shift || true
  if [ -x "$PROJECT_ROOT/.venv/bin/$tool" ]; then
    "$PROJECT_ROOT/.venv/bin/$tool" "$@"
  elif have "$tool"; then
    "$tool" "$@"
  elif have pipx; then
    pipx run "$tool" "$@"
  else
    die "Tool '$tool' not found. Run: $0 ensure"
  fi
}

cmd_ensure() {
  local mode="${1:-pipx}"
  case "$mode" in
    pipx) ensure_tools_pipx ;;
    venv) ensure_venv ;;
    both) ensure_tools_pipx; ensure_venv ;;
    *) die "Unknown mode '$mode' (use: pipx|venv|both)" ;;
  esac
  log "Done."
}

cmd_fmt() {
  run_tool black "$PROJECT_ROOT/yaml_config_loader" "$PROJECT_ROOT/tests"
  if run_tool ruff -q --help | grep -q 'format'; then
    run_tool ruff format "$PROJECT_ROOT/yaml_config_loader" "$PROJECT_ROOT/tests"
  fi
}

cmd_lint() {
  run_tool ruff check "$PROJECT_ROOT/yaml_config_loader" "$PROJECT_ROOT/tests"
}

cmd_type() {
  run_tool mypy --strict "$PROJECT_ROOT/yaml_config_loader"
}

cmd_test() {
  if [ -x "$PROJECT_ROOT/.venv/bin/python" ]; then
    "$PROJECT_ROOT/.venv/bin/python" -m pytest -q
  else
    python3 -m pytest -q
  fi
}

cmd_build() {
  mkdir -p "$PROJECT_ROOT/dist"
  if have pipx; then
    pipx run build "$PROJECT_ROOT"
  elif [ -x "$PROJECT_ROOT/.venv/bin/python" ]; then
    "$PROJECT_ROOT/.venv/bin/python" -m build "$PROJECT_ROOT"
  else
    python3 -m build "$PROJECT_ROOT"
  fi
}

cmd_check() {
  run_tool twine check "$PROJECT_ROOT/dist"/*
}

cmd_upload_test() {
  run_tool twine upload --repository testpypi "$PROJECT_ROOT/dist"/*
}

cmd_upload() {
  run_tool twine upload "$PROJECT_ROOT/dist"/*
}

usage() {
  cat <<EOF
Usage: $(basename "$0") <command> [args]

Commands:
  ensure [pipx|venv|both]  Install/upgrade tools via pipx or .venv (default: pipx)
  fmt                      Format code (black, ruff format)
  lint                     Lint (ruff check)
  type                     Type-check (mypy --strict)
  test                     Run tests (pytest)
  build                    Build sdist and wheel
  check                    Twine check dist/*
  upload-test              Upload to TestPyPI
  upload                   Upload to PyPI

Examples:
  $0 ensure both
  $0 fmt && $0 lint && $0 type
  $0 build && $0 check && $0 upload-test
EOF
}

main() {
  local cmd="${1:-help}"; shift || true
  case "$cmd" in
    ensure) cmd_ensure "${1:-pipx}" ;;
    fmt)    cmd_fmt ;;
    lint)   cmd_lint ;;
    type)   cmd_type ;;
    test)   cmd_test ;;
    build)  cmd_build ;;
    check)  cmd_check ;;
    upload-test) cmd_upload_test ;;
    upload) cmd_upload ;;
    help|--help|-h) usage ;;
    *) usage; exit 1 ;;
  esac
}

main "$@"


