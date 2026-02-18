#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SUPABASE_MIGRATIONS_DIR="supabase/migrations"
STRICT_MODE=0

usage() {
  cat <<'EOF'
Usage: scripts/check_migration_mirror.sh [--strict]

Options:
  --strict  Exit with non-zero status if migration issues are detected.
  -h, --help  Show this help.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --strict)
      STRICT_MODE=1
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

for cmd in find basename sort mktemp wc cut uniq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 2
  fi
done

cleanup_files=()
register_tmp() {
  cleanup_files+=("$1")
}
cleanup() {
  if [[ ${#cleanup_files[@]} -gt 0 ]]; then
    rm -f "${cleanup_files[@]}"
  fi
}
trap cleanup EXIT

list_sql_files() {
  local source_dir="$1"
  find "$source_dir" -maxdepth 1 -type f -name '*.sql' -exec basename {} \; | sort
}

supabase_files="$(mktemp)"
register_tmp "$supabase_files"
list_sql_files "$SUPABASE_MIGRATIONS_DIR" > "$supabase_files"

invalid_name_file="$(mktemp)"
register_tmp "$invalid_name_file"
while IFS= read -r migration_name; do
  if [[ ! "$migration_name" =~ ^[0-9]{14}_.+\.sql$ ]]; then
    printf "%s\n" "$migration_name" >> "$invalid_name_file"
  fi
done < "$supabase_files"

timestamp_collision_file="$(mktemp)"
register_tmp "$timestamp_collision_file"
cut -c1-14 "$supabase_files" | sort | uniq -d > "$timestamp_collision_file"

echo "=== Migration Source Check (supabase/migrations) ==="
echo
echo "supabase/migrations SQL count: $(wc -l < "$supabase_files" | tr -d ' ')"
echo "Mirror status: retired (supabase/migrations is sole source of truth)"
echo

drift_detected=0
print_diff() {
  local title="$1"
  local diff_file="$2"
  local fail_on_drift="${3:-0}"
  echo "-- $title --"
  if [[ -s "$diff_file" ]]; then
    cat "$diff_file"
    if [[ "$fail_on_drift" -eq 1 ]]; then
      drift_detected=1
    fi
  else
    echo "(none)"
  fi
  echo
}

print_diff "Invalid migration filename format (expected YYYYMMDDHHMMSS_name.sql)" "$invalid_name_file" 1
print_diff "Timestamp collisions (duplicate 14-digit prefixes)" "$timestamp_collision_file" 1

if [[ "$STRICT_MODE" -eq 1 && "$drift_detected" -eq 1 ]]; then
  echo "Strict mode enabled: migration issues detected."
  exit 1
fi

if [[ "$STRICT_MODE" -eq 1 ]]; then
  echo "Strict mode enabled: migrations look good."
fi
