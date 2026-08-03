#!/bin/sh
# Remove orphan chunk files left in a 'Deleted' state by the atticd garbage
# collector, plus their database rows.
#
# The scheduled atticd GC never retries these: run_reap_orphan_chunks only
# selects chunks in 'Valid' state (see server/src/gc.rs), so chunks whose
# remote-file deletion previously failed are stuck forever with their files
# still on disk. Typically they come from a cache that was destroyed.
#
# Safe to run while atticd is up: 'Deleted' chunks are invisible to all
# normal queries, so no live upload/GC path touches these files.
#
# Usage:
#   sudo scripts/attic-cleanup-orphans.sh          # delete files + purge rows
#   sudo scripts/attic-cleanup-orphans.sh --dry-run # list files, delete nothing
set -eu

DB="${ATTIC_DB:-/var/lib/atticd/server.db}"
STORAGE="${ATTIC_STORAGE:-/var/lib/atticd/storage}"
DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "Must be run as root (files under ${STORAGE} are root-owned)." >&2
  echo "  sudo $0" >&2
  exit 1
fi

[ -f "$DB" ] || { echo "Database not found: $DB" >&2; exit 1; }
[ -d "$STORAGE" ] || { echo "Storage not found: $STORAGE" >&2; exit 1; }
command -v sqlite3 >/dev/null 2>&1 || { echo "sqlite3 CLI not found" >&2; exit 1; }

deleted_names="$(mktemp /tmp/attic-deleted.XXXXXX)"
found_files="$(mktemp /tmp/attic-found.XXXXXX)"
trap 'rm -f "$deleted_names" "$found_files"' EXIT

echo "Collecting 'Deleted' chunk filenames from ${DB} ..."
sqlite3 "$DB" "
  SELECT substr(remote_file,
                instr(remote_file, 'name\":\"') + 7,
                instr(remote_file, '\"}') - instr(remote_file, 'name\":\"') - 7)
  FROM chunk
  WHERE state = 'D' AND remote_file LIKE '%name\":\"%';
" | sort -u > "$deleted_names"

name_count="$(wc -l < "$deleted_names" | tr -d ' ')"
if [ "$name_count" -eq 0 ]; then
  echo "No orphan chunks in 'Deleted' state. Nothing to do."
  exit 0
fi
echo "Found $name_count orphan chunk files referenced in the DB."

find "$STORAGE" -type f -name '*.chunk' > "$found_files"

# Keep only files whose name appears in the Deleted set. The storage tree is
# sharded (<h>/<hh>/<uuid>.chunk), so match on the basename only.
to_delete="$(mktemp /tmp/attic-to-delete.XXXXXX)"
trap 'rm -f "$deleted_names" "$found_files" "$to_delete"' EXIT
awk 'NR == FNR { del[$0] = 1; next }
     { n = $0; sub(/.*\//, "", n); if (n in del) print }' \
  "$deleted_names" "$found_files" > "$to_delete"

delete_count="$(wc -l < "$to_delete" | tr -d ' ')"
echo "On disk: $delete_count orphan chunk files to remove."

if [ "$delete_count" -eq 0 ]; then
  echo "Nothing to delete."
  exit 0
fi

if [ "$DRY_RUN" = "1" ]; then
  echo "--dry-run: would delete the above files and purge $name_count DB rows."
  sed 's/^/  /' "$to_delete" | head -20
  echo "  ... ($delete_count total)"
  exit 0
fi

xargs rm -f < "$to_delete"
echo "Deleted $delete_count orphan chunk files."

echo "Purging 'Deleted' rows from ${DB} ..."
rows_before="$(sqlite3 "$DB" "SELECT COUNT(*) FROM chunk WHERE state = 'D';")"
if ! sqlite3 -cmd '.timeout 5000' "$DB" \
  "DELETE FROM chunk WHERE state = 'D';" >/dev/null 2>&1; then
  echo "DB purge failed (atticd may hold a write lock)." >&2
  echo "The files are already gone; purge the $rows_before rows later with:" >&2
  echo "  sudo sqlite3 $DB \"DELETE FROM chunk WHERE state='D';\"" >&2
  exit 1
fi
rows_after="$(sqlite3 "$DB" "SELECT COUNT(*) FROM chunk WHERE state = 'D';")"
echo "Purged $((rows_before - rows_after)) 'Deleted' rows from the database."

echo "Done."
