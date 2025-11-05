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
        && \
    rm -rf /var/lib/apt/lists/*

# Verify installations
RUN node --version && \
    npm --version && \
    zip --version && \
    jq --version

LABEL org.opencontainers.image.source="https://github.com/carr-james/eurorack-docker"
LABEL org.opencontainers.image.description="KiBot + Antora build environment for Eurorack hardware documentation"
LABEL org.opencontainers.image.licenses="MIT"
