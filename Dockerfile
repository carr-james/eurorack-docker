# KiBot + Antora build environment for Eurorack hardware docs.
#
# Built from debian:sid (KiCad 10) rather than ghcr.io/inti-cmnb/kicad_auto:dev_k9,
# which pinned us to KiCad 9 and to whatever that image happened to contain.
#
# linux/amd64 only, and that is a deliberate constraint rather than an oversight.
# The 3D renders need pcb2blender, whose importer is published against exact
# Blender versions (4.2 LTS, 4.5 LTS, 5.0, 5.1). Debian packages none of those —
# trixie has 4.3.2, sid has 5.0.1 — and official Blender, which does match, is
# published for linux-x64 only. Both arm64 routes were tested and both fail:
# Debian's 5.0.1 registers the importer but drops every annotation-declared
# operator property under Python 3.14 (import_x3d then rejects `global_scale`),
# and trixie's 4.3.2 fails the importer's own version assertion outright.
#
# Until Blender publishes Linux arm64 builds, or pcb2blender targets a version
# Debian actually ships, Apple Silicon should run this image under emulation
# with `DOCKER_DEFAULT_PLATFORM=linux/amd64`. KiAuto times out at default
# settings there; see kiauto_time_out_scale in the repo READMEs.

FROM --platform=linux/amd64 debian:sid

ENV DEBIAN_FRONTEND=noninteractive \
    LIBGL_ALWAYS_SOFTWARE=1 \
    PYTHONUNBUFFERED=1

# KiCad 10 + libraries, the X stack KiAuto drives, and the tools KiBot shells
# out to. Blender itself comes from upstream's tarball further down, not apt.
RUN apt-get update -qq && \
    apt-get install -y -qq --no-install-recommends \
        kicad \
        kicad-symbols \
        kicad-footprints \
        kicad-packages3d \
        kicad-templates \
        xvfb \
        xdotool \
        xclip \
        x11-utils \
        wmctrl \
        libgl1-mesa-dri \
        libglu1-mesa \
        libgl1 \
        libegl1 \
        libxi6 \
        libxrender1 \
        libxxf86vm1 \
        libxfixes3 \
        libsm6 \
        xz-utils \
        imagemagick \
        ghostscript \
        poppler-utils \
        librsvg2-bin \
        python3 \
        python3-pip \
        python3-venv \
        python3-wxgtk4.0 \
        python3-lxml \
        python3-numpy \
        python3-bs4 \
        git \
        nodejs \
        npm \
        zip \
        unzip \
        jq \
        curl \
        ca-certificates \
        && \
    rm -rf /var/lib/apt/lists/*

# KiBot + KiAuto. Debian marks the system Python as externally managed, so
# install into a venv rather than fighting PEP 668 — but it must inherit
# system site-packages, since KiBot imports wx and KiCad's pcbnew bindings,
# both of which come from apt and can't be pip-installed.
#
# --no-compile is load-bearing: KiBot rewrites its own modules at import time
# via kibot.macros, and pip's byte-compilation shadows that with stale .pyc
# files, so every plug-in fails to import at runtime.
RUN python3 -m venv --system-site-packages /opt/kibot-venv && \
    /opt/kibot-venv/bin/pip install --no-cache-dir --upgrade pip && \
    /opt/kibot-venv/bin/pip install --no-cache-dir --no-compile kibot kiauto InteractiveHtmlBom

ENV PATH="/opt/kibot-venv/bin:${PATH}"

# Carried over from the inti-cmnb base this image replaced, where it lived in
# /etc/gitconfig and was easy to miss.
#
# GitHub Actions container jobs run as root against a workspace owned by the
# runner user, so without safe.directory every actions/checkout fails with
# "detected dubious ownership" and exit 128. The file protocol allowance is
# needed for submodules resolved via local paths, which git blocks by default.
RUN git config --system --add safe.directory '*' && \
    git config --system protocol.file.allow always

# Boards still carry v9-era ${KICAD9_*_DIR} paths for their 3D models. KiCad 10
# only defines KICAD10_*, so those models resolve to nothing and drop out of the
# renders without failing the build. Define both until the files are migrated.
ENV KICAD10_SYMBOL_DIR=/usr/share/kicad/symbols \
    KICAD10_FOOTPRINT_DIR=/usr/share/kicad/footprints \
    KICAD10_3DMODEL_DIR=/usr/share/kicad/3dmodels \
    KICAD10_TEMPLATE_DIR=/usr/share/kicad/template \
    KICAD9_SYMBOL_DIR=/usr/share/kicad/symbols \
    KICAD9_FOOTPRINT_DIR=/usr/share/kicad/footprints \
    KICAD9_3DMODEL_DIR=/usr/share/kicad/3dmodels \
    KICAD9_TEMPLATE_DIR=/usr/share/kicad/template

# Blender 4.2 LTS, from upstream rather than apt. The version is pinned to the
# pcb2blender importer below — the importer bundles cp311 wheels matching this
# tarball's embedded Python, and asserts on its Blender version at register
# time, so the pair moves together or not at all.
ARG BLENDER_VERSION=4.2.5
ARG BLENDER_DIR=/opt/blender-${BLENDER_VERSION}-linux-x64
RUN curl -sL -o /tmp/blender.tar.xz \
        https://download.blender.org/release/Blender4.2/blender-${BLENDER_VERSION}-linux-x64.tar.xz && \
    tar -xf /tmp/blender.tar.xz -C /opt && \
    ln -s ${BLENDER_DIR}/blender /usr/local/bin/blender && \
    rm /tmp/blender.tar.xz

# pcb2blender's importer, used by .kibot/scripts/render_boards_blender.py to
# turn KiBot's .pcb3d output into the 3D renders on the docs site. That script
# calls addon_utils.enable('pcb2blender'), so the package has to land in a
# directory of exactly that name. Its wheels install into Blender's own
# interpreter, not the system one.
ARG PCB2BLENDER_VERSION=v2.17.3-k9.0-b4.2lts
ARG PCB2BLENDER_IMPORTER=pcb2blender_importer_v2-17-3_b4-2lts.zip
RUN ADDON_DIR=${BLENDER_DIR}/4.2/scripts/addons_core/pcb2blender && \
    BLENDER_PYTHON=${BLENDER_DIR}/4.2/python/bin/python3.11 && \
    mkdir -p ${ADDON_DIR} && \
    curl -sL -o /tmp/importer.zip \
        https://github.com/30350n/pcb2blender/releases/download/${PCB2BLENDER_VERSION}/${PCB2BLENDER_IMPORTER} && \
    unzip -q /tmp/importer.zip -d ${ADDON_DIR} && \
    ${BLENDER_PYTHON} -m pip install --no-index --find-links=${ADDON_DIR}/wheels \
        error_helper pillow pybind11 skia-python && \
    rm /tmp/importer.zip

# ImageMagick's default policy blocks PDF/PS conversion, which pcb_print needs.
RUN for p in /etc/ImageMagick-7/policy.xml /etc/ImageMagick-6/policy.xml; do \
        [ -f "$p" ] && sed -i 's/rights="none" pattern="\(PDF\|PS\|EPS\)"/rights="read|write" pattern="\1"/g' "$p" || true; \
    done

RUN kicad-cli version && \
    python3 -c "import pcbnew; print('pcbnew', pcbnew.GetBuildVersion())" && \
    kibot --version && \
    pcbnew_do --help > /dev/null && \
    blender --version | head -1 && \
    blender --background --python-expr "\
import addon_utils, bpy, sys;\
ok = bool(addon_utils.enable('pcb2blender', default_set=True, persistent=False));\
ok = ok and hasattr(bpy.ops, 'pcb2blender') and hasattr(bpy.ops.pcb2blender, 'import_pcb3d');\
print('pcb2blender importer:', 'OK' if ok else 'FAILED');\
sys.exit(0 if ok else 1)" && \
    node --version && npm --version && jq --version

LABEL org.opencontainers.image.source="https://github.com/carr-james/eurorack-docker"
LABEL org.opencontainers.image.description="KiBot + Antora build environment for Eurorack hardware documentation"
LABEL org.opencontainers.image.licenses="MIT"
