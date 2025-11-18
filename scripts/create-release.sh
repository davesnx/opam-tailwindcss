#!/bin/bash
# ABOUTME: Creates a GitHub release for a specific Tailwind CSS version with binary assets
# ABOUTME: Used by GitHub Actions to automate releases. Can be run manually with VERSION env var.

set -e

command -v curl >/dev/null 2>&1 || { echo "curl is required"; exit 1; }
command -v jq   >/dev/null 2>&1 || { echo "jq is required"; exit 1; }
command -v gh   >/dev/null 2>&1 || { echo "gh (GitHub CLI) is required"; exit 1; }

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

# Get the repository name (owner/repo) from git remote
repo_url=$(git remote get-url davesnx 2>/dev/null || git remote get-url origin)
repo_name=$(echo "$repo_url" | sed 's/.*github.com[:/]\(.*\)\.git$/\1/' | sed 's/.*github.com[:/]\(.*\)$/\1/')
echo "Using repository: $repo_name"

# Check if this release already exists
if gh release view "$semver" --repo "$repo_name" >/dev/null 2>&1; then
    echo "Release $semver already exists. Skipping."
    exit 0
fi

# Store the repo directory
repo_dir=$(pwd)

# Create temporary directory for downloads
temp_dir=$(mktemp -d)
trap "rm -rf $temp_dir" EXIT

cd "$temp_dir" || exit 1

# Download binaries
url="https://github.com/tailwindlabs/tailwindcss/releases/download/$tag_name"
echo "Downloading binaries from $url"

# Required binaries (must exist for all versions)
required_binaries=(
    "tailwindcss-linux-arm64"
    "tailwindcss-linux-x64"
    "tailwindcss-macos-arm64"
    "tailwindcss-macos-x64"
    "tailwindcss-windows-x64.exe"
)

# Optional binaries (may not exist in all versions)
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

# Download CHANGELOG
echo "Downloading CHANGELOG..."
changelog_url="https://raw.githubusercontent.com/tailwindlabs/tailwindcss/$tag_name/CHANGELOG.md"
if curl -f -L "$changelog_url" -o CHANGELOG.md; then
    # Extract release notes for this version (first section of changelog, up to 50 lines)
    release_notes=$(head -n 50 CHANGELOG.md)
else
    echo "Warning: Could not download CHANGELOG"
    release_notes="Tailwind CSS $tag_name

See upstream release: https://github.com/tailwindlabs/tailwindcss/releases/tag/$tag_name"
fi

echo ""
echo "Creating GitHub release $semver..."

# Go back to repo directory to run gh commands
cd "$repo_dir" || exit 1

# Create the release with binaries from temp directory
if [ -n "$release_notes" ]; then
    gh release create "$semver" \
        --repo "$repo_name" \
        --title "Tailwind CSS $tag_name" \
        --notes "$release_notes" \
        "$temp_dir"/tailwindcss-* || {
        echo "Error: Failed to create release"
        exit 1
    }
else
    gh release create "$semver" \
        --repo "$repo_name" \
        --title "Tailwind CSS $tag_name" \
        --notes "Tailwind CSS $tag_name" \
        "$temp_dir"/tailwindcss-* || {
        echo "Error: Failed to create release"
        exit 1
    }
fi

echo "Successfully created release: $semver"
echo "Release URL: https://github.com/$repo_name/releases/tag/$semver"
echo "release_created=$semver" >> $GITHUB_OUTPUT 2>/dev/null || true

