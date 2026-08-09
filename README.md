# Eurorack Docker

Custom Docker image for building Eurorack hardware documentation.

## Base Image

Built from `debian:sid`, which packages **KiCad 10**. Previously based on
[ghcr.io/inti-cmnb/kicad_auto:dev_k9](https://github.com/INTI-CMNB/KiBot), which
pinned us to KiCad 9 and to whatever that image happened to ship.

Contents:
- **KiCad 10** plus the symbol, footprint, 3D model and template libraries
- **KiBot + KiAuto** (pip, in a venv that inherits system site-packages)
- **Blender 4.2 LTS + pcb2blender importer** — for the `.pcb3d` 3D renders
- **Xvfb / xdotool / wmctrl** — the X stack KiAuto drives
- **Ghostscript, Poppler, librsvg, ImageMagick** — what KiBot shells out to
- **Node.js & npm** — for Antora documentation builds
- **zip / unzip / jq** — packaging and JSON processing in workflows

## Architecture

`linux/amd64` only. That is a deliberate constraint, not an oversight.

The 3D renders depend on pcb2blender, whose importer is published against exact
Blender versions (4.2 LTS, 4.5 LTS, 5.0, 5.1). Debian packages none of those —
trixie has 4.3.2, sid has 5.0.1 — and official Blender, which does match, is
published for `linux-x64` only. Both arm64 routes were tested and both fail:

- Debian sid's Blender 5.0.1 registers the importer, but under Python 3.14 every
  annotation-declared operator property is dropped, so `import_x3d` rejects
  `global_scale` at render time.
- Debian trixie's Blender 4.3.2 fails the importer's own version assertion, and
  the operator never registers at all.

Everything *except* Blender does run natively on arm64 — the full KiBot output
set for a board takes ~20s there versus timing out under emulation. If that
becomes worth having, the split is viable; it just needs the docs pipeline to
tolerate a missing `blender` rather than failing with exit 127.

**On Apple Silicon, run this image with `DOCKER_DEFAULT_PLATFORM=linux/amd64`.**

### Notes for future maintenance

Non-obvious things this image depends on, all of which fail at runtime rather
than build time if changed:

- The venv is created with `--system-site-packages`. KiBot imports `wx` and
  KiCad's `pcbnew` bindings, which come from apt and cannot be pip-installed.
- KiBot is installed with `--no-compile`. It rewrites its own modules at import
  time via `kibot.macros`, and pip's byte-compilation shadows that with stale
  `.pyc` files, making every plug-in fail to import.
- The Blender version and the pcb2blender importer version are a matched pair.
  The importer bundles wheels built for Blender's embedded Python and asserts on
  its Blender version at register time — bump them together or not at all.
- `render_boards_blender.py` calls `addon_utils.enable('pcb2blender')`, so the
  addon must live in a directory of exactly that name.

The build ends with an assertion that the importer registers and exposes
`import_pcb3d`, so a mismatched pair fails the image build rather than silently
producing blank renders.

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

On Apple Silicon, the platform must be forced:

```bash
DOCKER_DEFAULT_PLATFORM=linux/amd64 docker build -t eurorack-docker .
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
