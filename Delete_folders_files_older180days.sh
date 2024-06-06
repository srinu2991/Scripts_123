#!/bin/bash

# Define the directory to search. You can change this to any directory you want to search.
SEARCH_DIR="/path/to/your/directory"

# Ensure the search directory exists
if [ ! -d "$SEARCH_DIR" ]; then
  echo "Directory $SEARCH_DIR does not exist."
  exit 1
fi

# Find and delete directories older than 180 days, including their contents
find "$SEARCH_DIR" -type d -mtime +180 -exec rm -rf {} +

# After deleting directories, do a final cleanup pass for any remaining files that were missed
find "$SEARCH_DIR" -type f -mtime +180 -exec rm -f {} +
