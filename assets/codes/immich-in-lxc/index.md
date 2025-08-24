---
layout: default_container
---
# Script for brutal-forced uninstallation of immich

- [Direct download link to move_existing_immich_dependencies.sh][script link]

[script link]: ./move_existing_immich_dependencies.sh


Directly downloading a shell script can be dangerous, so please read the script
below before running it. LLMs are really good at understanding scripts, so you
can ask them to learn about the script and what it does. You can also ask them
to modify the script to suit your needs.

Again, if you are using `pre-install.sh` to install the dependencies, this
script *should* be safe. Always back up first.


```shell
#!/usr/bin/env bash

# This script reads file lists of existing entries and moves them from /usr/local
# to a consolidated backup location. It then cleans up the empty parent directories.
#
# It operates in two phases:
# 1. MOVE: Moves all files, symlinks, and special wildcarded groups (.so.*, vips-modules-*).
# 2. CLEANUP: Removes the now-empty parent directories from /usr/local.
#
# SAFETY: This script runs in DRY RUN mode by default.
# To perform the actual operations, run with the --live flag.

set -euo pipefail

# --- Configuration ---
LISTS_DIR="./stow_existing_lists"
BACKUP_DIR="$HOME/usr_local_backup_$(date +%Y-%m-%d)"

# Script Mode
DRY_RUN=true
if [[ "${1:-}" == "--live" ]]; then
  DRY_RUN=false
  echo "!!!!!!!! WARNING: LIVE MODE ENABLED. FILES WILL BE MOVED AND DIRECTORIES REMOVED. !!!!!!!!"
else
  echo "INFO: Running in DRY RUN mode. No changes will be made. Use --live to execute."
fi
sleep 2


if [ ! -d "$LISTS_DIR" ]; then
  echo "Error: Input directory with file lists not found at '$LISTS_DIR'."
  exit 1
fi

mkdir -p "$BACKUP_DIR"
echo "Backup destination: $BACKUP_DIR"
echo "--------------------------------------------------"

# Temp files for tracking state
processed_patterns_log=$(mktemp)
dirs_to_cleanup_log=$(mktemp)
trap 'rm -f -- "$processed_patterns_log" "$dirs_to_cleanup_log"' EXIT


# First, move files and symlinks
echo "PHASE 1: Moving all specified files and symlinks..."

for list_file in "$LISTS_DIR"/*-existing-entries.txt; do
  echo "Processing list: $(basename "$list_file")"
  while read -r entry_path || [[ -n "$entry_path" ]]; do

    pattern_to_move="$entry_path"

    # Wildcard handling
    if [[ "$entry_path" == *.so.* ]]; then
      pattern_to_move="${entry_path%%.so.*}.so.*"
    elif [[ "$entry_path" == *"/vips-modules-"* ]]; then
      pattern_to_move="${entry_path%%/vips-modules-*}/vips-modules-*"
    fi

    # Skip if already processed
    if grep -qFx "$pattern_to_move" "$processed_patterns_log"; then continue; fi
    echo "$pattern_to_move" >> "$processed_patterns_log"

    # Record parent directory for cleanup phase
    echo "$(dirname "$entry_path")" >> "$dirs_to_cleanup_log"

    # Prepare destination and move
    dest_parent_dir="$BACKUP_DIR/$(dirname "$entry_path")"

    if $DRY_RUN; then
      shopt -s nullglob
      found_items=0
      for item in $pattern_to_move; do
         if [ -e "$item" ] || [ -L "$item" ]; then
            echo "  [DRY RUN] Would move '$item' to '$dest_parent_dir/'"
            found_items=$((found_items + 1))
         fi
      done
      if [ $found_items -eq 0 ]; then
         echo "  [DRY RUN] Source not found (or already moved): '$pattern_to_move'"
      fi
      shopt -u nullglob
    else
      # Live mode
      shopt -s nullglob
      files_to_move=($pattern_to_move)
      shopt -u nullglob
      if [ ${#files_to_move[@]} -gt 0 ]; then
        echo "  -> Moving '$pattern_to_move' to '$dest_parent_dir/'"
        mkdir -p "$dest_parent_dir"
        mv -v $pattern_to_move "$dest_parent_dir/"
      else
        echo "  -> Source not found (or already moved): '$pattern_to_move'"
      fi
    fi
  done < "$list_file"
done


# Then cleanup empty parent directories
echo ""
echo "PHASE 2: Cleaning up empty parent directories..."

# Get a unique list of directories, sorted by longest path first (reverse sort)
# This ensures we try to remove child directories before their parents.
mapfile -t sorted_dirs < <(sort -r -u "$dirs_to_cleanup_log")

for dir_path in "${sorted_dirs[@]}"; do
  # Ensure we don't try to remove /usr/local itself or its direct children
  if [[ "$(echo "$dir_path" | tr -cd '/' | wc -c)" -le 3 ]]; then
      continue
  fi

  if $DRY_RUN; then
    if [ -d "$dir_path" ]; then
      echo "  [DRY RUN] Would attempt to remove empty directory '$dir_path'"
    fi
  else
    # Live mode
    if [ -d "$dir_path" ]; then
      # Use rmdir, which fails safely if the directory is not empty.
      # The "|| true" suppresses the error message for non-empty dirs.
      rmdir "$dir_path" 2>/dev/null || true
    fi
  fi
done


echo "--------------------------------------------------"
echo "Script finished."
if $DRY_RUN; then
  echo "Dry run complete. No changes were made."
else
  echo "Live run complete. Files have been moved to $BACKUP_DIR and empty directories cleaned."
fi
```