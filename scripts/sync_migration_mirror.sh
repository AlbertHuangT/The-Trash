#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: scripts/sync_migration_mirror.sh [--dry-run]

Options:
  --dry-run  Print deprecation notice without side effects.
  -h, --help Show this help.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --dry-run)
      DRY_RUN=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Dry run: migration mirror sync is deprecated."
else
  echo "Migration mirror sync is deprecated."
fi
echo "No files were copied."
echo "Use supabase/migrations as the only source of truth."
