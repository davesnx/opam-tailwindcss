#!/bin/bash
# ABOUTME: Creates a GitHub release with binaries from /bin/ as release assets
# ABOUTME: Used by GitHub Actions to automate releases. Can be run manually with VERSION env var.

set -e

command -v jq >/dev/null 2>&1 || { echo "jq is required"; exit 1; }
command -v gh >/dev/null 2>&1 || { echo "gh (GitHub CLI) is required"; exit 1; }

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

echo "Creating release for Tailwind CSS version: $tag_name"

# Convert tag to semver (v4.1.2 -> 4.1.2)
semver="${tag_name#v}"

# Get the repository name (owner/repo) from git remote
# Use REMOTE_NAME env var if set, otherwise default to origin
remote_name="${REMOTE_NAME:-origin}"
repo_url=$(git remote get-url "$remote_name")
repo_name=$(echo "$repo_url" | sed 's/.*github.com[:/]\(.*\)\.git$/\1/' | sed 's/.*github.com[:/]\(.*\)$/\1/')
echo "Using repository: $repo_name (remote: $remote_name)"

# Check if this release already exists
if gh release view "$semver" --repo "$repo_name" >/dev/null 2>&1; then
    echo "Release $semver already exists. Skipping."
    exit 0
fi

# Verify binaries exist in /bin/
if [ ! -d "bin" ] || [ -z "$(ls -A bin/tailwindcss-* 2>/dev/null)" ]; then
    echo "Error: No binaries found in /bin/ directory"
    echo "Run scripts/update-and-tag.sh first to download binaries"
    exit 1
fi

# Get release notes from CHANGES.md if it exists
if [ -f "CHANGES.md" ]; then
    # Extract release notes for this version (first section of changelog, up to 50 lines)
    release_notes=$(head -n 50 CHANGES.md)
else
    release_notes="Tailwind CSS $tag_name

See upstream release: https://github.com/tailwindlabs/tailwindcss/releases/tag/$tag_name"
fi

echo ""
echo "Creating tarball with all binaries..."

# Create a tarball with all binaries in a bin/ directory structure
tar_name="tailwindcss-$semver.tar.gz"
tar czf "$tar_name" -C . bin/

echo "Creating GitHub release $semver with binaries and tarball..."

# Create the release with individual binaries AND the tarball
if [ -n "$release_notes" ]; then
    gh release create "$semver" \
        --repo "$repo_name" \
        --title "Tailwind CSS $tag_name" \
        --notes "$release_notes" \
        bin/tailwindcss-* "$tar_name" || {
        echo "Error: Failed to create release"
        exit 1
    }
else
    gh release create "$semver" \
        --repo "$repo_name" \
        --title "Tailwind CSS $tag_name" \
        --notes "Tailwind CSS $tag_name" \
        bin/tailwindcss-* "$tar_name" || {
        echo "Error: Failed to create release"
        exit 1
    }
fi

echo "Successfully created release: $semver"
echo "Release URL: https://github.com/$repo_name/releases/tag/$semver"
echo "Tarball: $tar_name"
echo "release_created=$semver" >> $GITHUB_OUTPUT 2>/dev/null || true

