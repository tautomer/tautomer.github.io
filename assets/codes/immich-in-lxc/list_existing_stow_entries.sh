#!/usr/bin/env bash

# This script checks filesystem entries (files and symlinks) from a stow source directory
# against the target system.
#
# For each package, it generates a single list of entries that ALREADY EXIST in /usr/local.
# The paths in the list are stripped of the stow prefix (e.g., /usr/local/bin/vips).
# Entries that do not exist in the target are ignored.

set -euo pipefail

# --- Configuration ---
# The base directory where your stow packages are located.
STOW_BASE_DIR="/opt/stow"
# The directory where the output lists will be saved.
OUTPUT_DIR="./stow_existing_lists"

# --- Main Script ---

# Check if the base directory exists
if [ ! -d "$STOW_BASE_DIR" ]; then
  echo "Error: Stow base directory not found at '$STOW_BASE_DIR'."
  exit 1
fi

# Create the output directory
mkdir -p "$OUTPUT_DIR"
echo "Output will be saved in: $OUTPUT_DIR"
echo "--------------------------------------------------"

# Loop through each package directory in the stow base directory
for package_path in "$STOW_BASE_DIR"/*; do
  # Ensure we're only processing directories
  if [ -d "$package_path" ]; then
    package_name=$(basename "$package_path")
    source_prefix_dir="$package_path/usr/local"
    
    echo "Processing package: $package_name"

    # Check if the package contains a usr/local directory to process
    if [ ! -d "$source_prefix_dir" ]; then
      echo "  -> Skipping, no 'usr/local' directory found in '$package_path'."
      continue
    fi

    # Define the single output file for the current package
    existing_list="$OUTPUT_DIR/${package_name}-existing-entries.txt"

    # Clear the previous list for this package
    > "$existing_list"

    # Find all files and symbolic links within the package's structure
    find "$source_prefix_dir" \( -type f -o -type l \) | while read -r source_entry; do
      
      # Determine the corresponding target path in the system
      # This removes the '/opt/stow/packagename' prefix.
      target_entry="${source_entry#$package_path}"
      
      # If the target entry exists in the system...
      if [ -e "$target_entry" ]; then
        # ...write its TARGET PATH to the list.
        echo "$target_entry" >> "$existing_list"
      fi
      # Missing entries are ignored as requested.
    done

    # Report the results for the package
    existing_count=$(wc -l < "$existing_list")
    
    echo "  -> Found $existing_count existing entr(y/ies). List: $existing_list"
    echo ""
  fi
done

echo "--------------------------------------------------"
echo "Script finished successfully."