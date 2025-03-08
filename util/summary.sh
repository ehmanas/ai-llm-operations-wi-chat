#!/bin/bash

function graceful_exit
{
      echo -e "Exiting due to an error occuring at $(TZ=US/Eastern date '+%m/%d/%Y %H:%M:%S EST.')\n" | tee -a $LOG_FILE
      echo -e "Some results before the error may have been logged to $LOG_FILE\n"
      echo -e "Here is the error message: $1\n"
      exit 1
}

# Capitalize first letter of each word and replace dashes with spaces
function format_link_text() {
    echo "$1" | sed 's/-/ /g' | sed 's/\b\(.\)/\u\1/g'
}

# fully qualified script path and name
SC_SCRIPT_DIR_NAME=$(readlink -f "$0")
echo SC_SCRIPT_DIR_NAME=$SC_SCRIPT_DIR_NAME
# fully qualified script path
SC_SCRIPT_DIR=$(dirname "$SC_SCRIPT_DIR_NAME")
echo SC_SCRIPT_DIR=$SC_SCRIPT_DIR

cd $SC_SCRIPT_DIR || graceful_exit "could not change to script directory"
source ../config.properties

cd $WI_SRC_DIR || graceful_exit "could not change to src directory"

rm -f SUMMARY.md

# Find all markdown files and create SUMMARY.md
find . -maxdepth 1 -name "*.md" -not -name "SUMMARY.md" -not -name "chat.md" -print0 | sort -f -z | while IFS= read -r -d '' file; do
    # Remove leading ./ from the path
    clean_path="${file#./}"
    # Get filename without extension for the link text
    filename=$(basename "$clean_path" .md)
    # Create markdown link, encoding spaces in the path
    # Replace spaces with %20 in the path portion
    encoded_path="${clean_path// /%20}"
    formatted_text=$(format_link_text "$filename")
    echo "- [$formatted_text](./$encoded_path)" >> SUMMARY.md
done
sed -i '1i\- [Chat](chat.md)' SUMMARY.md
