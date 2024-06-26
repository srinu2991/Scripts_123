#!/bin/bash

# Variables
SEARCH_DIR="/path/to/search"
EMAIL_TO="recipient@example.com"
EMAIL_SUBJECT="Latest recoll.pdf file"
EMAIL_BODY="Please find the attached recoll.pdf file."

# Find the latest directory ending with "mge_pdf"
latest_dir=$(find "$SEARCH_DIR" -type d -name '*mge_pdf' -print0 | xargs -0 ls -dt | head -n 1)

if [ -z "$latest_dir" ]; then
  echo "No directory ending with 'mge_pdf' found."
  exit 1
fi

echo "Latest directory: $latest_dir"

# Check for the presence of recoll.pdf inside the latest directory
recoll_file="$latest_dir/recoll.pdf"

if [ ! -f "$recoll_file" ]; then
  echo "recoll.pdf not found in the latest directory."
  exit 1
fi

echo "recoll.pdf found: $recoll_file"

# Send an email with the recoll.pdf attached
echo "$EMAIL_BODY" | mail -s "$EMAIL_SUBJECT" -a "$recoll_file" "$EMAIL_TO"

echo "Email sent to $EMAIL_TO with recoll.pdf attached."
