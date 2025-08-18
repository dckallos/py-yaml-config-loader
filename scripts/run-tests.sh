#!/usr/bin/env bash
set -euo pipefail

# Run project tests via pytest.
# - Prefers the project's virtual environment if present
# - Runs all tests by default
# - Can target a specific file (or any pytest target) for modular execution
# - Forwards additional args directly to pytest

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
DEFAULT_TESTS_DIR="$PROJECT_ROOT/tests"

log() { printf '[%s] %s\n' "$(date +'%H:%M:%S')" "$*"; }
warn() { printf '[%s] WARN: %s\n' "$(date +'%H:%M:%S')" "$*" >&2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

venv_python() {
  local vpy="$PROJECT_ROOT/.venv/bin/python"
  if [ -x "$vpy" ]; then
    echo "$vpy"
    return 0
  fi
  return 1
}

choose_python() {
  if vpy=$(venv_python); then
    echo "$vpy"
    return 0
  fi
  if have python3; then
    warn "Using system python3 (no .venv detected). For best results, run: bash scripts/dev-tools.sh ensure venv"
    echo python3
    return 0
  fi
  die "No suitable Python found. Install python3 or create a venv at .venv."
}

print_help() {
  cat <<EOF
Usage: $(basename "$0") [--file PATH] [pytest-args ...]

Examples:
  # Run all tests (preferred .venv if present)
  $(basename "$0")

  # Run a single file
  $(basename "$0") --file tests/test_core_basic.py

  # Run with extra pytest args (e.g., verbose and keyword selection)
  $(basename "$0") -v -k LOG_LEVEL

Notes:
  - Prefers .venv at project root. If not present, falls back to system python3.
  - Additional arguments are forwarded directly to pytest.
EOF
}

declare -a TEST_TARGETS=()
declare -a PYTEST_ARGS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --file)
      shift
      [ $# -gt 0 ] || die "--file requires a PATH argument"
      TEST_TARGETS+=("$1")
      shift
      ;;
    -h|--help)
      print_help
      exit 0
      ;;
    *)
      # Everything else is passed through to pytest (paths, node ids, flags)
      PYTEST_ARGS+=("$1")
      shift
      ;;
  esac
done

PYTHON_CMD="$(choose_python)"

# Default to tests/ if no explicit targets provided
if [ ${#TEST_TARGETS[@]} -eq 0 ]; then
  # If the user supplied explicit non-flag args, let pytest handle them; otherwise add default dir.
  has_explicit_target=0
  if [ ${#PYTEST_ARGS[@]} -gt 0 ]; then
    for a in "${PYTEST_ARGS[@]}"; do
      case "$a" in
        -* ) ;; # flag
        * ) has_explicit_target=1 ;;
      esac
    done
  fi
  if [ "$has_explicit_target" -eq 0 ]; then
    TEST_TARGETS+=("$DEFAULT_TESTS_DIR")
  fi
fi

# Sanity check for pytest availability in chosen interpreter
if ! "$PYTHON_CMD" - <<'PY'
try:
    import pytest  # noqa: F401
except Exception as exc:
    raise SystemExit(3)
PY
then
  die "pytest not available in the chosen Python. Create the venv with: bash scripts/dev-tools.sh ensure venv"
fi

# Optional: quick dependency check for runtime import (PyYAML) used by tests
if ! "$PYTHON_CMD" - <<'PY'
try:
    import yaml  # noqa: F401
except Exception:
    raise SystemExit(3)
PY
then
  warn "PyYAML not available in the chosen Python. Tests may fail. Prefer using: bash scripts/dev-tools.sh ensure venv"
fi

cd "$PROJECT_ROOT"

# Build the command as an array for robustness
declare -a pytest_cmd=("$PYTHON_CMD" -m pytest)
if [ ${#TEST_TARGETS[@]} -gt 0 ]; then
  pytest_cmd+=("${TEST_TARGETS[@]}")
fi
if [ ${#PYTEST_ARGS[@]} -gt 0 ]; then
  pytest_cmd+=("${PYTEST_ARGS[@]}")
fi

# Print the command in a shell-quoted form
if command -v printf >/dev/null 2>&1; then
  # shellcheck disable=SC2059
  printf -v _cmd_str '%q ' "${pytest_cmd[@]}"
  log "Running tests via: ${_cmd_str% }"
else
  log "Running tests via: ${pytest_cmd[*]-}"
fi

exec "${pytest_cmd[@]}"


