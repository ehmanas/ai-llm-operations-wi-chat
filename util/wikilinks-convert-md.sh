#!/bin/bash

## Note: this is not complete (does not work yet).
## Kept becuse I did not work to lose current progress.

# Find all .md files in current directory
for file in *.md; do
    # Check if file exists and is a regular file
    if [ -f "$file" ]; then
        echo "Processing $file..."

        # Create a temporary file
        temp_file=$(mktemp)

        # TODO: I need the ability to encode the resulting text.md string
        # Example: echo "string to encode" | jq -sRr @uri
        #
        # Use sed to convert [[text]] to [text](text.md)
        # This handles simple wikilinks without aliases
        sed "s/\[\[\([^]|]*\)\]\]/[\1](\1.md)/g" "$file" > "$temp_file"

        # Replace original file with modified content
        mv "$temp_file" "$file"
    fi
done

echo "Conversion complete!"
