#!/bin/bash
# Startup script for Jupyter notebook server.
# Home directory initialization is handled by the before-notebook.d/init-home.sh hook
# which runs automatically via the base image's start.sh entrypoint chain.

cd "${HOME}"

exec start-notebook.sh \
  --ip=0.0.0.0 \
  --port=8888 \
  --no-browser \
  --allow-root \
  --ServerApp.token="" \
  --ServerApp.password="" \
  --ServerApp.allow_origin="*" \
  --ServerApp.allow_remote_access=True \
  --ServerApp.authenticate_prometheus=False \
  --ServerApp.base_url="${NB_PREFIX:-/}" \
  --ServerApp.default_url="/lab"
