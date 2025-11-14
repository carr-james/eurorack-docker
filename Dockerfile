# Custom Docker image for Eurorack hardware documentation builds
# Based on KiBot's kicad_auto image with additional tools pre-installed

FROM ghcr.io/inti-cmnb/kicad_auto:dev_k9

# Install Node.js, npm, and other build tools
# This avoids reinstalling them on every build
RUN apt-get update -qq && \
    apt-get install -y -qq \
        nodejs \
        npm \
        zip \
        jq \
        python3-pip \
        wget \
        xz-utils \
        libgl1 \
        libglu1-mesa \
        libxi6 \
        libxrender1 \
        && \
    rm -rf /var/lib/apt/lists/*

# Install Blender 4.2 LTS
RUN cd /tmp && \
    wget -q https://download.blender.org/release/Blender4.2/blender-4.2.5-linux-x64.tar.xz && \
    tar -xf blender-4.2.5-linux-x64.tar.xz -C /opt && \
    ln -s /opt/blender-4.2.5-linux-x64/blender /usr/local/bin/blender && \
    rm blender-4.2.5-linux-x64.tar.xz

# Install pcb2blender importer plugin for Blender
# Using v2.17.3 for Blender 4.2 LTS
RUN BLENDER_VERSION=$(blender --version | head -1 | grep -oP '\d+\.\d+' | head -1) && \
    echo "Detected Blender version: $BLENDER_VERSION" && \
    BLENDER_PYTHON=/opt/blender-4.2.5-linux-x64/4.2/python/bin/python3.11 && \
    wget -q https://github.com/30350n/pcb2blender/releases/download/v2.17.3-k9.0-b4.2lts/pcb2blender_importer_v2-17-3_b4-2lts.zip -O /tmp/pcb2blender.zip && \
    mkdir -p /opt/blender-4.2.5-linux-x64/${BLENDER_VERSION}/scripts/addons_core/pcb2blender && \
    unzip -q /tmp/pcb2blender.zip -d /opt/blender-4.2.5-linux-x64/${BLENDER_VERSION}/scripts/addons_core/pcb2blender && \
    echo "Installing Python dependencies from wheels..." && \
    cd /opt/blender-4.2.5-linux-x64/${BLENDER_VERSION}/scripts/addons_core/pcb2blender && \
    $BLENDER_PYTHON -m pip install --no-index --find-links=wheels error_helper pillow pybind11 skia-python && \
    rm /tmp/pcb2blender.zip

# Verify installations
RUN node --version && \
    npm --version && \
    zip --version && \
    jq --version && \
    blender --version

LABEL org.opencontainers.image.source="https://github.com/carr-james/eurorack-docker"
LABEL org.opencontainers.image.description="KiBot + Antora build environment for Eurorack hardware documentation"
LABEL org.opencontainers.image.licenses="MIT"
