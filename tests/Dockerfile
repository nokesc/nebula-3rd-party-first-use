FROM mcr.microsoft.com/devcontainers/python:3

WORKDIR /workspace

# Install test dependencies
COPY tests/requirements.txt /tmp/requirements.txt
RUN pip install -r /tmp/requirements.txt

# Install ClamAV for binary scanning
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y clamav clamav-daemon \
    && rm -rf /var/lib/apt/lists/*
# Initialize virus definitions (suppress output to keep build log clean, or allow it)
# We accept that this might fail on some restricted networks, but it's standard.
RUN freshclam || echo "Warning: freshclam failed, scanner database might be outdated."

# Create a place for the non-root user to install tools
RUN mkdir -p /home/vscode/.local/bin && chown -R vscode:vscode /home/vscode/.local

# Switch to non-root user
USER vscode

# We will mount the repo at /workspace at runtime like:
# docker run -v $(pwd):/workspace ...
