#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

swift_rpcs=$(rg -o 'rpc\("[a-zA-Z0-9_]+' -n 'The Trash' \
  | sed -E 's/.*rpc\("//' \
  | tr 'A-Z' 'a-z' \
  | sort -u)

sql_functions=$(rg -n "create\s+or\s+replace\s+function" supabase/migrations -i \
  | sed -E 's/.*create[[:space:]]+or[[:space:]]+replace[[:space:]]+function[[:space:]]+((public\.)?[a-zA-Z0-9_]+).*/\1/I' \
  | sed 's/^public\.//' \
  | tr 'A-Z' 'a-z' \
  | sort -u)

# Helper to print sorted set difference A - B
set_diff() {
  comm -23 <(printf "%s\n" "$1" | sed '/^$/d' | sort -u) <(printf "%s\n" "$2" | sed '/^$/d' | sort -u)
}

echo "=== Backend Contract Check ==="
echo

echo "Swift RPC count: $(printf "%s\n" "$swift_rpcs" | sed '/^$/d' | wc -l | tr -d ' ')"
echo "Supabase migration function count: $(printf "%s\n" "$sql_functions" | sed '/^$/d' | wc -l | tr -d ' ')"
echo

echo "-- Swift RPCs missing in supabase/migrations --"
missing_in_sql=$(set_diff "$swift_rpcs" "$sql_functions" || true)
if [[ -n "${missing_in_sql}" ]]; then
  printf "%s\n" "$missing_in_sql"
else
  echo "(none)"
fi

echo
echo "-- SQL functions not called by any Swift RPC --"
unused_sql=$(set_diff "$sql_functions" "$swift_rpcs" || true)
if [[ -n "${unused_sql}" ]]; then
  printf "%s\n" "$unused_sql"
else
  echo "(none)"
fi
