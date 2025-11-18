#!/bin/bash

set -e

command -v curl >/dev/null 2>&1 || { echo "curl is required"; exit 1; }
command -v jq   >/dev/null 2>&1 || { echo "jq is required"; exit 1; }
command -v git  >/dev/null 2>&1 || { echo "git is required"; exit 1; }

echo "Fetching all Tailwind CSS releases..."
releases=$(curl -s "https://api.github.com/repos/tailwindlabs/tailwindcss/releases?per_page=100")

versions=$(echo "$releases" | jq -r '.[] | select(.tag_name | test("^v[3-9]\\.|^v[0-9][0-9]+\\.")) | .tag_name' | sort -V)

if [ -z "$versions" ]; then
    echo "No versions found to backfill"
    exit 1
fi

echo "Found versions to backfill:"
echo "$versions"
echo ""

# Process each version
for tag_name in $versions; do
    opam_version="tailwindcss.${tag_name#v}"

    # Check if tag already exists
    if git rev-parse "$opam_version" >/dev/null 2>&1; then
        echo "Skipping $opam_version (already exists)"
        continue
    fi

    echo "========================================="
    echo "Processing $tag_name -> $opam_version"
    echo "========================================="

    # Set VERSION environment variable and run update script
    export VERSION="$tag_name"

    if ./scripts/update-and-tag.sh; then
        echo "✓ Successfully processed $opam_version"
    else
        echo "✗ Failed to process $opam_version"
        echo "  You may need to investigate this version manually"
    fi

    echo ""
done

echo "========================================="
echo "Backfill complete!"
echo "========================================="
echo ""
echo "Created tags:"
git tag -l "tailwindcss.*" | tail -n 20
echo ""
echo "To push all tags, run:"
echo "  git push davesnx --tags"

