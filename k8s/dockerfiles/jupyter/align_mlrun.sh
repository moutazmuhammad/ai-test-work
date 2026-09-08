#!/bin/bash
# Align client MLRun version with the remote MLRun API server.
# Requires MLRUN_DBPATH to point at the server (e.g. http://mlrun-api:8080).

MLRUN_API_URL="${MLRUN_DBPATH:-http://mlrun-api:8080}"

CLIENT_MLRUN_VERSION=$(pip show mlrun | grep Version | awk '{print $2}')
SERVER_MLRUN_VERSION=$(curl -s "${MLRUN_API_URL}/api/v1/client-spec" | python3 -c "import sys, json; print(json.load(sys.stdin)['version'])" 2>/dev/null)

if [ -z "${SERVER_MLRUN_VERSION}" ]; then
  echo "Could not reach MLRun API at ${MLRUN_API_URL}, skipping version alignment."
  exit 0
fi

if [ "${CLIENT_MLRUN_VERSION}" = "${SERVER_MLRUN_VERSION}" ] || [ "${CLIENT_MLRUN_VERSION}" = "${SERVER_MLRUN_VERSION//-}" ]; then
  echo "Both server & client are aligned (${CLIENT_MLRUN_VERSION})."
else
  if [ "${CLIENT_MLRUN_VERSION}" ]; then
    echo "Server ${SERVER_MLRUN_VERSION} & client ${CLIENT_MLRUN_VERSION} are unaligned."
    echo "Updating client..."
    pip uninstall -y mlrun
  fi
  pip install mlrun[complete]==${SERVER_MLRUN_VERSION}
fi
