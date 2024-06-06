#!/bin/bash

# Define the directory to search. You can change this to any directory you want to search.
SEARCH_DIR="/path/to/your/directory"

# Ensure the search directory exists
if [ ! -d "$SEARCH_DIR" ]; then
  echo "Directory $SEARCH_DIR does not exist."
  exit 1
fi

# Find and delete files and folders older than 180 days
find "$SEARCH_DIR" -mindepth 1 -mtime +180 -print0 | while IFS= read -r -d '' item; do
  if [ -e "$item" ]; then
    echo "Deleting $item"
    rm -rf "$item"
  else
    echo "File or directory $item does not exist."
  fi
done
