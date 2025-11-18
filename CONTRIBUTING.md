# Contributing

## Release Process

This repository automatically tracks Tailwind CSS releases. Each Tailwind CSS
version gets a corresponding git tag in this repository.

### Versioning

- Tailwind CSS `v4.1.2` → Git tag `tailwindcss.4.1.2`
- Tailwind CSS `v3.4.1` → Git tag `tailwindcss.3.4.1`

### Automated Updates

The repository uses a GitHub Action (`.github/workflows/update-tailwind.yml`) to:
1. Check for new Tailwind CSS releases daily
2. Download the platform-specific binaries
3. Update the CHANGES.md with the upstream changelog
4. Commit the changes
5. Create and push a new git tag

### Manual Updates

To manually trigger an update for a specific version:

1. Go to the Actions tab in GitHub
2. Select "Update Tailwind CSS" workflow
3. Click "Run workflow"
4. Enter the version (e.g., `v4.1.2`) or leave empty for latest
5. Click "Run workflow"

Alternatively, run locally:

```bash
VERSION=v4.1.2 ./scripts/update-and-tag.sh
git push origin --tags
```

### Backfilling Historical Versions

To backfill previous Tailwind CSS versions from v3.0.0 onwards:

```bash
./scripts/backfill-versions.sh
```

This will:
- Fetch all Tailwind CSS releases from v3.0.0 onwards
- Download binaries for each version
- Create corresponding git tags
- Skip versions that already have tags

**Note:** The backfill process can take a while. You may want to push tags
incrementally or review them before pushing:

```bash
# Review created tags
git tag -l "tailwindcss.*"

# Push all tags
git push origin --tags
```

## Development

### Testing Locally

After updating binaries, test that the correct binary is selected:

```bash
# Test the runtest alias
dune runtest

# Or run directly
opam exec -- tailwindcss --help
```

### File Structure

- `bin/` - Platform-specific Tailwind CSS binaries
- `dune` - Dune build rules for installing the correct binary per platform
- `tailwindcss.opam` - Opam package definition
- `scripts/update-and-tag.sh` - Script to update to a specific version
- `scripts/backfill-versions.sh` - Script to backfill historical versions
- `.github/workflows/update-tailwind.yml` - GitHub Action for automated updates

