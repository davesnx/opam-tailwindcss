#!/bin/bash
# ABOUTME: Downloads Tailwind CSS binaries and creates a git tag (without committing binaries)
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

# Convert tag to semver (v4.1.2 -> 4.1.2)
semver="${tag_name#v}"

# Check if this version already exists as a git tag
if git rev-parse "$semver" >/dev/null 2>&1; then
    echo "Version $semver already exists. Skipping."
    exit 0
fi

# Download binaries to /bin/ (gitignored, not committed)
url="https://github.com/tailwindlabs/tailwindcss/releases/download/$tag_name"
echo "Downloading binaries from $url to /bin/"

mkdir -p bin
cd bin || exit 1

# Required binaries
required_binaries=(
    "tailwindcss-linux-arm64"
    "tailwindcss-linux-x64"
    "tailwindcss-macos-arm64"
    "tailwindcss-macos-x64"
    "tailwindcss-windows-x64.exe"
)

# Optional binaries
optional_binaries=(
    "tailwindcss-windows-arm64.exe"
)

# Download required binaries
for binary in "${required_binaries[@]}"; do
    echo "Downloading $binary..."
    if ! curl -f -LO "${url}/${binary}"; then
        echo "Error: Failed to download required binary $binary"
        exit 1
    fi
    chmod +x "$binary" 2>/dev/null || true
done

# Download optional binaries
for binary in "${optional_binaries[@]}"; do
    echo "Downloading $binary (optional)..."
    if curl -f -LO "${url}/${binary}"; then
        chmod +x "$binary" 2>/dev/null || true
    else
        echo "⚠ Skipping optional binary $binary (not available for this version)"
    fi
done

cd .. || exit 1

# Download CHANGELOG
echo "Downloading CHANGELOG..."
curl -f -L "https://raw.githubusercontent.com/tailwindlabs/tailwindcss/$tag_name/CHANGELOG.md" -o CHANGES.md || {
    echo "Warning: Could not download CHANGELOG, keeping existing"
}

# Commit binaries and CHANGES.md
echo "Committing binaries and changelog..."
git add -f bin/tailwindcss-* CHANGES.md 2>/dev/null
git commit -m "Release Tailwind CSS $tag_name" || {
    echo "No changes to commit"
}

# Create annotated tag
git tag -a "$semver" -m "Tailwind CSS $tag_name"

echo "Successfully created tag: $semver (with binaries)"
echo "tag_version=$semver" >> $GITHUB_OUTPUT 2>/dev/null || true

