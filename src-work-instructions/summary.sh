#!/bin/bash

rm SUMMARY.md

# Find all markdown files and create SUMMARY.md
find . -maxdepth 1 -name "*.md" -not -name "SUMMARY.md" -not -name "chat.md" -print0 | sort -f -z | while IFS= read -r -d '' file; do
    # Remove leading ./ from the path
    clean_path="${file#./}"
    # Get filename without extension for the link text
    filename=$(basename "$clean_path" .md)
    # Create markdown link, encoding spaces in the path
    # Replace spaces with %20 in the path portion
    encoded_path="${clean_path// /%20}"
    echo "- [$filename](./$encoded_path)" >> SUMMARY.md
done
sed -i '1i\- [chat](chat.md)' SUMMARY.md
