# GitHub Actions Workflows

## Docker Build (`docker-build.yml`)

Automatically builds and pushes Docker images to GitHub Container Registry (ghcr.io).

### Triggers

- **Push to main/madhava/stage2**: Builds and pushes with branch tag + `latest`
- **Version tags** (`v*`): Builds and pushes with semantic version tags
- **Pull requests**: Builds only (no push)
- **Manual**: Via Actions tab → "Build and Push Docker Image" → "Run workflow"

### Tags Created

```
ghcr.io/YOUR_USERNAME/epi-syrian-refugees:latest          # main branch
ghcr.io/YOUR_USERNAME/epi-syrian-refugees:main            # main branch
ghcr.io/YOUR_USERNAME/epi-syrian-refugees:madhava-stage2  # madhava/stage2 branch
ghcr.io/YOUR_USERNAME/epi-syrian-refugees:v1.0.0          # git tag v1.0.0
ghcr.io/YOUR_USERNAME/epi-syrian-refugees:1.0             # git tag v1.0.0
ghcr.io/YOUR_USERNAME/epi-syrian-refugees:main-abc1234    # commit SHA
```

### Pull the Image

```bash
# Pull latest
docker pull ghcr.io/YOUR_USERNAME/epi-syrian-refugees:latest

# Pull specific version
docker pull ghcr.io/YOUR_USERNAME/epi-syrian-refugees:v1.0.0
```

**Note**: Replace `YOUR_USERNAME` with your GitHub username or org name.

### Make Image Public

By default, images are private. To make public:

1. Go to: `https://github.com/YOUR_USERNAME?tab=packages`
2. Click on `epi-syrian-refugees` package
3. Click "Package settings"
4. Scroll to "Danger Zone"
5. Click "Change visibility" → "Public"

### Caching

Uses GitHub Actions cache to speed up builds:
- First build: ~30-60 min
- Subsequent builds: ~5-15 min (if only R packages changed)

### Manual Trigger

1. Go to Actions tab
2. Select "Build and Push Docker Image"
3. Click "Run workflow"
4. Choose branch
5. Click "Run workflow"

### Create Version Tag

```bash
git tag v1.0.0
git push origin v1.0.0
```

This triggers a build with version tags.

## Optional: Docker Hub

To also push to Docker Hub, add these secrets:

1. Go to Settings → Secrets and variables → Actions
2. Add:
   - `DOCKERHUB_USERNAME`: Your Docker Hub username
   - `DOCKERHUB_TOKEN`: Docker Hub access token

Then uncomment Docker Hub section in workflow (if added).
