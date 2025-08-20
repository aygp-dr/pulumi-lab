#!/bin/bash
# Publish README.org files to README.md using Emacs one-liner
# Usage: ./publish-readme.sh [README.org files...]

set -e

if [ $# -eq 0 ]; then
    # Find all README.org files
    readmes=$(find . -name "README.org" -type f)
    if [ -z "$readmes" ]; then
        echo "No README.org files found"
        exit 0
    fi
    set -- $readmes
fi

echo "📚 Publishing README.org files to README.md"
echo "Using Emacs one-liner approach"
echo

for org_file in "$@"; do
    if [ ! -f "$org_file" ]; then
        echo "❌ File not found: $org_file"
        continue
    fi
    
    dir=$(dirname "$org_file")
    filename=$(basename "$org_file")
    
    echo "🚀 Publishing $org_file..."
    
    # The actual one-liner
    (cd "$dir" && emacs -Q --batch -l org "$filename" -f org-md-export-to-markdown)
    
    if [ $? -eq 0 ]; then
        echo "✅ Success: $dir/README.md"
    else
        echo "❌ Failed: $org_file"
    fi
done

echo
echo "🎉 Done!"