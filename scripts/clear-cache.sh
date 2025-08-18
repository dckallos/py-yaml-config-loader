#!/usr/bin/env bash
set -euo pipefail

# 🧭 Determine project root relative to this script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

EMOJI_FIND="🔍"
EMOJI_CLEAN="🧹"
EMOJI_TRASH="🗑️"
EMOJI_DONE="✅"
EMOJI_WARN="⚠️"

DRY_RUN=${1:-}
if [[ "${DRY_RUN:-}" == "--help" || "${DRY_RUN:-}" == "-h" ]]; then
  cat <<EOF
Usage: $(basename "$0") [--dry-run]

Recursively remove Python cache directories and compiled files from the project.

Targets:
  - __pycache__
  - .pytest_cache, .mypy_cache, .ruff_cache, .hypothesis
  - .tox, .nox
  - .ipynb_checkpoints, .cache
  - *.pyc, *.pyo

Environment:
  PROJECT_ROOT  Set to override the detected project root.

Options:
  --dry-run     List matches without deleting.
EOF
  exit 0
fi

# 🛡️ Safety checks
if [[ ! -d "$PROJECT_ROOT" ]]; then
  echo "$EMOJI_WARN Project root not found: $PROJECT_ROOT"
  exit 1
fi

if [[ ! -f "$PROJECT_ROOT/pyproject.toml" && ! -f "$PROJECT_ROOT/requirements.txt" ]]; then
  echo "$EMOJI_WARN pyproject.toml/requirements.txt not found in $PROJECT_ROOT — refusing to run."
  echo "     Set PROJECT_ROOT to your repo root if needed."
  exit 1
fi

echo "$EMOJI_FIND Scanning for cache directories and compiled files under: $PROJECT_ROOT"

declare -a DIR_PATTERNS=(
  "__pycache__"
  ".pytest_cache"
  ".mypy_cache"
  ".ruff_cache"
  ".hypothesis"
  ".tox"
  ".nox"
  ".ipynb_checkpoints"
  ".cache"
)

total_dirs_removed=0
total_files_removed=0

# Exclusion heuristics: avoid removing inside common virtual env dirs
should_skip_dir() {
  local path="$1"
  if [[ "$path" == *"/.venv/"* || "$path" == *"/venv/"* || "$path" == *"/.env/"* ]]; then
    return 0
  fi
  return 1
}

for pat in "${DIR_PATTERNS[@]}"; do
  echo "$EMOJI_CLEAN Searching for '$pat' directories..."
  count_this_pattern=0
  while IFS= read -r -d '' dir; do
    # Skip deletions under virtual environments
    if should_skip_dir "$dir/"; then
      continue
    fi
    echo "$EMOJI_TRASH $([[ -n "$DRY_RUN" ]] && echo "Would remove" || echo "Removing") directory: $dir"
    if [[ -z "$DRY_RUN" ]]; then
      rm -rf "$dir"
    fi
    ((count_this_pattern++))
  done < <(find "$PROJECT_ROOT" -type d -name "$pat" -print0 2>/dev/null || true)
  total_dirs_removed=$((total_dirs_removed + count_this_pattern))
done

echo "$EMOJI_CLEAN Searching for compiled Python files (*.pyc, *.pyo)..."
while IFS= read -r -d '' file; do
  # Avoid deleting compiled files in venvs
  if should_skip_dir "$(dirname "$file")/"; then
    continue
  fi
  echo "$EMOJI_TRASH $([[ -n "$DRY_RUN" ]] && echo "Would remove" || echo "Removing") file: $file"
  if [[ -z "$DRY_RUN" ]]; then
    rm -f "$file"
  fi
  ((total_files_removed++))
done < <(find "$PROJECT_ROOT" \( -name "*.pyc" -o -name "*.pyo" \) -print0 2>/dev/null || true)

echo "$EMOJI_DONE Finished. Directories removed: $total_dirs_removed, files removed: $total_files_removed"


