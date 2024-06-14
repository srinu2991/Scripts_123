#!/bin/bash

# Define an array of directories to search. Add as many directories as you need.
SEARCH_DIRS=("/path/to/first/directory" "/path/to/second/directory" "/path/to/third/directory")

# Iterate over each directory in the list
for SEARCH_DIR in "${SEARCH_DIRS[@]}"; do

  # Ensure the search directory exists
  if [ ! -d "$SEARCH_DIR" ]; then
    echo "Directory $SEARCH_DIR does not exist."
    continue
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

done
