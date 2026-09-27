# GitHub Actions Setup for PowerShell Gallery Publishing

This repository includes a GitHub Actions workflow that automatically validates and publishes the `tcs.openapi` module to the PowerShell Gallery.

## 🚀 Features

- **Automated Validation**: Tests module manifest, runs PSScriptAnalyzer, and validates imports
- **Version Checking**: Prevents accidental republishing of existing versions
- **Secure Publishing**: Uses encrypted secrets for API keys
- **Release Creation**: Automatically creates GitHub releases for tagged versions
- **Manual Triggers**: Allows manual workflow execution with options

## 📋 Prerequisites

### 1. PowerShell Gallery API Key

You need to obtain an API key from PowerShell Gallery:

1. Go to [PowerShell Gallery](https://www.powershellgallery.com/)
2. Sign in with your Microsoft account
3. Click on your username → "API Keys"
4. Create a new API key with "Push new packages and package versions" scope
5. Copy the generated API key

### 2. GitHub Repository Secrets

Add the API key as a repository secret:

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Name: `PSGALLERY_API_KEY`
5. Value: Your PowerShell Gallery API key
6. Click **Add secret**

## 🔄 Workflow Triggers

### Automatic Triggers

The workflow automatically runs when you push a version tag:

```bash
# Create and push a version tag
git tag v0.1.8
git push origin v0.1.8
```

### Manual Triggers

You can also trigger the workflow manually:

1. Go to **Actions** tab in your repository
2. Select "Publish to PowerShell Gallery" workflow
3. Click **Run workflow**
4. Optionally enable "Force publish" to override existing versions

## 📦 Publishing Process

### 1. Validation Stage

The workflow performs these validation steps:

- ✅ **Manifest Testing**: Validates the module manifest (.psd1)
- ✅ **PSScriptAnalyzer**: Checks code quality and best practices
- ✅ **Import Testing**: Ensures the module imports without errors
- ✅ **Version Checking**: Verifies version doesn't already exist in PowerShell Gallery

Pull requests also run the **consumer checks** in `ci-validate.yml`: every tcs module that
depends on tcs.openapi (tcs.azure, tcs.jira, tcs.confluence, tcs.intune.packaging, tcs.utils) is
imported against the tcs.openapi being changed and its own smoke tests are run. tcs.utils is a
private repository; add a `CONSUMER_REPOS_TOKEN` repository secret (a token with read access to
it) to include it, otherwise it is skipped with a warning.

### 2. Publishing Stage

If validation passes:

- 📤 **Publishes** the module to PowerShell Gallery
- 🏷️ **Creates** a GitHub release (for tag-triggered builds)
- 📢 **Notifies** about the results

## 🏷️ Version Management

### Semantic Versioning

Follow semantic versioning (SemVer) for your tags:

- `v1.0.0` - Major release
- `v0.1.8` - Minor update  
- `v0.1.7` - Patch/bugfix

### Update Module Version

Before creating a tag, update the version in your module manifest:

```powershell
# In tcs.openapi.psd1
ModuleVersion = '0.1.8'
```

## 🛠️ Workflow Configuration

### Environment Variables

```yaml
env:
  MODULE_NAME: 'tcs.openapi'
   MODULE_PATH: './modules/tcs.openapi'
```

### Customization

You can customize the workflow by modifying `.github/workflows/publish-to-psgallery.yml`:

- Change PowerShell version requirements
- Add additional validation steps
- Modify notification settings
- Add deployment to additional repositories

## 🔍 Troubleshooting

### Common Issues

1. **API Key Invalid**
   - Verify the secret name is exactly `PSGALLERY_API_KEY`
   - Ensure the API key has publishing permissions
   - Check if the API key has expired

2. **Version Already Exists**
   - Update the version in `tcs.openapi.psd1`
   - Or use the "Force publish" option for testing

3. **PSScriptAnalyzer Failures**
   - Fix any code quality issues reported
   - Review the analyzer output in the workflow logs

4. **Module Import Failures**
   - Check for syntax errors in your PowerShell files
   - Ensure all dependencies are properly defined

### Viewing Logs

1. Go to **Actions** tab
2. Click on the workflow run
3. Expand the job steps to see detailed logs

## 📝 Example Workflow

Here's a typical workflow for publishing a new version:

```bash
# 1. Make your changes to the module
# 2. Update tests and documentation
# 3. Update version in manifest
# 4. Commit changes
git add .
git commit -m "Release v0.1.8: Add new features and improvements"

# 5. Create and push version tag
git tag v0.1.8
git push origin main
git push origin v0.1.8

# 6. GitHub Actions automatically validates and publishes
# 7. Check the Actions tab for progress
# 8. Once complete, verify on PowerShell Gallery
```

## 🔒 Security Best Practices

- ✅ Never commit API keys to the repository
- ✅ Use repository secrets for sensitive data
- ✅ Consider using environment protection rules for production
- ✅ Regularly rotate API keys
- ✅ Review workflow permissions

## 📚 Additional Resources

- [PowerShell Gallery Publishing Guide](https://docs.microsoft.com/en-us/powershell/scripting/gallery/how-to/publishing-packages)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [PowerShell Module Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/developer/module/writing-a-windows-powershell-module)