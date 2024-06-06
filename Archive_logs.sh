#!/bin/bash

# Define the directory to search. You can change this to any directory you want to search.
SEARCH_DIR="/path/to/your/directory"

# Ensure the search directory exists
if [ ! -d "$SEARCH_DIR" ]; then
  echo "Directory $SEARCH_DIR does not exist."
  exit 1
fi

# First, find and delete files older than 180 days
find "$SEARCH_DIR" -type f -mtime +180 -print0 | while IFS= read -r -d '' file; do
  if [ -e "$file" ]; then
    echo "Deleting file $file"
    rm -f "$file"
  else
    echo "File $file does not exist."
  fi
done

# Next, find and delete empty directories older than 180 days
find "$SEARCH_DIR" -type d -empty -mtime +180 -print0 | while IFS= read -r -d '' dir; do
  if [ -e "$dir" ]; then
    echo "Deleting empty directory $dir"
    rmdir "$dir"
  else
    echo "Directory $dir does not exist."
  fi
done

# Finally, find and delete non-empty directories older than 180 days
find "$SEARCH_DIR" -type d -mtime +180 -print0 | while IFS= read -r -d '' dir; do
  if [ -e "$dir" ]; then
    echo "Deleting directory $dir"
    rm -rf "$dir"
  else
    echo "Directory $dir does not exist."
  fi
done

