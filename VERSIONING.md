# Version Management

This project uses automatic version management through a `tag.txt` file.

## 🚀 How it works

1. **Update version**: Edit `tag.txt` with the new version (e.g., `v1.4.0`)
2. **Push to main**: Commit and push changes to main branch
3. **Automatic pipeline**: GitHub Actions automatically:
   - Reads version from `tag.txt`
   - Validates version format
   - Creates Git tag if version is new
   - Builds and publishes release
   - Updates binary versions

## 📝 Version format

Use semantic versioning with `v` prefix:
- ✅ `v1.0.0`
- ✅ `v1.2.3` 
- ✅ `v2.0.0`
- ❌ `1.0.0` (missing v prefix)
- ❌ `v1.0` (incomplete)

## 📋 Workflow

```bash
# 1. Update version in tag.txt
echo "v1.4.0" > tag.txt

# 2. Commit and push
git add tag.txt
git commit -m "Bump version to v1.4.0"
git push origin main

# 3. Watch the pipeline
# - GitHub Actions will automatically create tag v1.4.0
# - Build release with proper version in binaries
# - Publish to GitHub Releases
```

## 🔄 Pipeline stages

The automated pipeline runs in this order:

1. **Lint** → Code quality checks
2. **Test** → Unit tests with coverage  
3. **Security** → Vulnerability scanning
4. **Build Test** → Compilation verification
5. **Version Check & Auto-Tag** → Read `tag.txt`, create Git tag if new
6. **Release Build & Publish** → GoReleaser build and GitHub release

## 🎯 Benefits

- ✅ **Centralized version management** - Single source of truth
- ✅ **Automatic Git tagging** - No manual tag creation needed
- ✅ **Version synchronization** - Binary versions match Git tags
- ✅ **CI/CD integration** - Seamless release process
- ✅ **Developer friendly** - Just edit one file

## 📊 Pipeline behavior

- **Same version**: Only runs CI checks (Lint, Test, Security, Build Test)
- **New version**: Runs full pipeline including release
- **Invalid format**: Pipeline fails with clear error message

## 🔧 Manual release (if needed)

You can still trigger manual releases:

```bash
# Workflow dispatch with custom tag
gh workflow run pipeline.yml -f tag=v1.4.1
```

## 🐛 Troubleshooting

**Q: Pipeline didn't create a release?**
- Check if version in `tag.txt` already exists as Git tag
- Verify version format is correct (`v1.2.3`)
- Ensure push was to `main` branch

**Q: Binary shows wrong version?**
- Version is read from `tag.txt` during build
- Check pipeline logs for version extraction
- Verify GoReleaser ldflags configuration
