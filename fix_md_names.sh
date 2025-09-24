#!/bin/bash

# Script to fix duplicate MD file names in solo directory by adding unique prefixes

SOLO_DIR="en01/Resources/solo"

# Function to add prefixes if not present
add_prefixes() {
  # For 考研英语一 - add year prefix to all files
  for year_dir in "$SOLO_DIR/考研英语一"/*/; do
    if [ -d "$year_dir" ]; then
      year=$(basename "$year_dir")
      find "$year_dir" -type f -name '*.md' ! -name "EN1_${year}_*" -exec bash -c 'file="$0"; dir=$(dirname "$file"); fname=$(basename "$file"); mv "$file" "$dir/EN1_'${year}'_${fname}"' {} \;
    fi
  done

  # For 考研英语二 - add year prefix to all files
  for year_dir in "$SOLO_DIR/考研英语二"/*/; do
    if [ -d "$year_dir" ]; then
      year=$(basename "$year_dir")
      find "$year_dir" -type f -name '*.md' ! -name "EN2_${year}_*" -exec bash -c 'file="$0"; dir=$(dirname "$file"); fname=$(basename "$file"); mv "$file" "$dir/EN2_'${year}'_${fname}"' {} \;
    fi
  done

  # For 通用 - fix double prefix issue and add year prefix
  for year_dir in "$SOLO_DIR/通用"/*/; do
    if [ -d "$year_dir" ]; then
      year=$(basename "$year_dir")
      
      # First, fix files with double GEN__ prefix (GEN__GEN__)
      find "$year_dir" -type f -name 'GEN__GEN__*.md' -exec bash -c 'file="$0"; dir=$(dirname "$file"); fname=$(basename "$file"); new_fname=${fname#GEN__GEN__}; mv "$file" "$dir/GEN_'${year}'_${new_fname}"' {} \;
      
      # Then fix files with single GEN__ prefix
      find "$year_dir" -type f -name 'GEN__*.md' ! -name "GEN_${year}_*" -exec bash -c 'file="$0"; dir=$(dirname "$file"); fname=$(basename "$file"); new_fname=${fname#GEN__}; mv "$file" "$dir/GEN_'${year}'_${new_fname}"' {} \;
      
      # Fix files with GEN_ prefix that are not GEN__
      find "$year_dir" -type f -name 'GEN_*.md' ! -name 'GEN__*.md' ! -name "GEN_${year}_*" -exec bash -c 'file="$0"; dir=$(dirname "$file"); fname=$(basename "$file"); new_fname=${fname#GEN_}; mv "$file" "$dir/GEN_'${year}'_${new_fname}"' {} \;
      
      # Fix any remaining files without proper prefix
      find "$year_dir" -type f -name '*.md' ! -name "GEN_${year}_*" -exec bash -c 'file="$0"; dir=$(dirname "$file"); fname=$(basename "$file"); mv "$file" "$dir/GEN_'${year}'_${fname}"' {} \;
    fi
  done
}

# Check for duplicates
echo "Checking for duplicate file names..."
duplicates=$(find "$SOLO_DIR" -type f -name '*.md' | xargs -n1 basename | sort | uniq -d)

if [ -n "$duplicates" ]; then
  echo "Duplicates found: $duplicates"
  echo "Adding prefixes..."
  add_prefixes
  echo "Prefixes added. Please rebuild the project."
else
  echo "No duplicates found."
fi