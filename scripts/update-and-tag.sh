#!/bin/bash
# ABOUTME: Downloads Tailwind CSS binaries for a specific version and creates a git tag
# ABOUTME: Used by GitHub Actions to automate releases. Can be run manually with VERSION env var.

set -e

command -v curl >/dev/null 2>&1 || { echo "curl is required"; exit 1; }
command -v jq   >/dev/null 2>&1 || { echo "jq is required"; exit 1; }
command -v git  >/dev/null 2>&1 || { echo "git is required"; exit 1; }

# Get version from environment or fetch latest
if [ -n "$VERSION" ]; then
    tag_name="$VERSION"
    # Ensure version starts with 'v'
    if [[ ! "$tag_name" =~ ^v ]]; then
        tag_name="v$tag_name"
    fi
else
    echo "Fetching latest Tailwind CSS release..."
    tag_name=$(curl -s https://api.github.com/repos/tailwindlabs/tailwindcss/releases/latest | jq -r .tag_name)
fi

echo "Processing Tailwind CSS version: $tag_name"

# Convert tag to opam version (v4.1.2 -> tailwindcss.4.1.2)
opam_version="tailwindcss.${tag_name#v}"

# Check if this version already exists as a git tag
if git rev-parse "$opam_version" >/dev/null 2>&1; then
    echo "Version $opam_version already exists. Skipping."
    exit 0
fi

# Download binaries
url="https://github.com/tailwindlabs/tailwindcss/releases/download/$tag_name"
echo "Downloading binaries from $url"

cd bin || exit 1

# Download each binary with error checking
for binary in \
    "tailwindcss-linux-arm64" \
    "tailwindcss-linux-x64" \
    "tailwindcss-macos-arm64" \
    "tailwindcss-macos-x64" \
    "tailwindcss-windows-arm64.exe" \
    "tailwindcss-windows-x64.exe"
do
    echo "Downloading $binary..."
    if ! curl -f -LO "${url}/${binary}"; then
        echo "Error: Failed to download $binary"
        exit 1
    fi
    # Make binaries executable (except Windows .exe files will be handled by OS)
    chmod +x "$binary" 2>/dev/null || true
done

cd .. || exit 1

# Download CHANGELOG
echo "Downloading CHANGELOG..."
curl -f -L "https://raw.githubusercontent.com/tailwindlabs/tailwindcss/$tag_name/CHANGELOG.md" -o CHANGES.md || {
    echo "Warning: Could not download CHANGELOG, keeping existing"
}

# Commit changes
git add bin/ CHANGES.md
git commit -m "Update to Tailwind CSS $tag_name" || {
    echo "No changes to commit"
}

# Create and annotate tag
git tag -a "$opam_version" -m "Tailwind CSS $tag_name"

echo "Successfully created tag: $opam_version"
echo "tag_created=$opam_version" >> $GITHUB_OUTPUT 2>/dev/null || true

