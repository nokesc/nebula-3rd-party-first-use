FROM mcr.microsoft.com/devcontainers/python:3

WORKDIR /workspace

# Install test dependencies
COPY tests/requirements.txt /tmp/requirements.txt
RUN pip install -r /tmp/requirements.txt

# Create a place for the non-root user to install tools
RUN mkdir -p /home/vscode/.local/bin && chown -R vscode:vscode /home/vscode/.local

# Switch to non-root user
USER vscode

# We will mount the repo at /workspace at runtime like:
# docker run -v $(pwd):/workspace ...
