# Eurorack Docker

Custom Docker image for building Eurorack hardware documentation.

## Base Image

Built on top of [ghcr.io/inti-cmnb/kicad_auto:dev_k9](https://github.com/INTI-CMNB/KiBot) which includes:
- KiCad 9
- KiBot
- Python and all necessary PCB automation tools

## Additional Tools

This image adds:
- **Node.js & npm** - For Antora documentation builds
- **zip** - For packaging artifacts
- **jq** - For JSON processing in workflows

## Usage

### In GitHub Actions

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/carr-james/eurorack-docker:latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npx antora antora-playbook.yml
```

### Local Builds

```bash
docker pull ghcr.io/carr-james/eurorack-docker:latest

docker run --rm \
  -v "$(pwd):/work" \
  -w /work \
  ghcr.io/carr-james/eurorack-docker:latest \
  bash -c "npm ci && npx antora antora-playbook.yml"
```

## Building Locally

```bash
docker build -t eurorack-docker .
```

## Automatic Builds

The image is automatically built and pushed to GitHub Container Registry when:
- Changes are pushed to the `Dockerfile`
- Changes are pushed to the build workflow
- Manually triggered via workflow_dispatch

## Image Location

Published at: `ghcr.io/carr-james/eurorack-docker:latest`

## License

MIT
