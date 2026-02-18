#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

RN_DIR="the-trash-rn"
SUPABASE_MIGRATIONS_DIR="supabase/migrations"
STRICT_MODE=0

usage() {
  cat <<'EOF'
Usage: scripts/check_backend_contracts.sh [--strict]

Options:
  --strict  Exit with non-zero status when drift is detected.
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

for cmd in rg sed tr sort comm wc mktemp awk; do
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

extract_rn_rpcs() {
  if [[ ! -d "$RN_DIR" ]]; then
    return 0
  fi

  (
    rg -o --no-filename --pcre2 '\.rpc\(\s*["'"'"'`][A-Za-z0-9_]+' "$RN_DIR" || true
  ) | sed -E 's/.*\.rpc\(\s*["'"'"'`]([A-Za-z0-9_]+).*/\1/' \
    | tr 'A-Z' 'a-z' \
    | sort -u
}

extract_sql_functions() {
  local source_dir="$1"
  (
    rg -o --no-filename -i --pcre2 'create\s+(?:or\s+replace\s+)?function\s+((?:"[^"]+"|[A-Za-z0-9_]+)(?:\.(?:"[^"]+"|[A-Za-z0-9_]+))?)' "$source_dir" || true
  ) | tr 'A-Z' 'a-z' \
    | sed -E 's/.*function[[:space:]]+//' \
    | sed -E 's/"//g' \
    | awk -F'.' '{print $NF}' \
    | sort -u
}

rn_rpcs_file="$(mktemp)"
register_tmp "$rn_rpcs_file"
extract_rn_rpcs > "$rn_rpcs_file"

sql_functions_supabase_file="$(mktemp)"
register_tmp "$sql_functions_supabase_file"
extract_sql_functions "$SUPABASE_MIGRATIONS_DIR" > "$sql_functions_supabase_file"

# Helper to print sorted set difference A - B
set_diff() {
  local left_file="$1"
  local right_file="$2"
  comm -23 "$left_file" "$right_file"
}

echo "=== Backend Contract Check (RN + Supabase) ==="
echo

echo "RN RPC count: $(wc -l < "$rn_rpcs_file" | tr -d ' ')"
echo "Supabase migration function count: $(wc -l < "$sql_functions_supabase_file" | tr -d ' ')"
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

missing_in_supabase_file="$(mktemp)"
register_tmp "$missing_in_supabase_file"
set_diff "$rn_rpcs_file" "$sql_functions_supabase_file" > "$missing_in_supabase_file" || true
print_diff "RPCs missing in supabase/migrations" "$missing_in_supabase_file" 1

unused_supabase_functions_file="$(mktemp)"
register_tmp "$unused_supabase_functions_file"
set_diff "$sql_functions_supabase_file" "$rn_rpcs_file" > "$unused_supabase_functions_file" || true
print_diff "Functions present in supabase/migrations but unused by current RN RPC calls" "$unused_supabase_functions_file" 0

if [[ "$STRICT_MODE" -eq 1 && "$drift_detected" -eq 1 ]]; then
  echo "Strict mode enabled: drift detected."
  exit 1
fi

if [[ "$STRICT_MODE" -eq 1 ]]; then
  echo "Strict mode enabled: no drift detected."
fi
