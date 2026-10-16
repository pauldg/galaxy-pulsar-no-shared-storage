#!/bin/sh
set -e
# Venv for Galaxy's remote metadata and Crypt4GH stage-in, built once from the mounted checkout.
if [ ! -x /venv-galaxy/bin/python ]; then
    python -m venv /venv-galaxy
    /venv-galaxy/bin/pip install --no-cache-dir -r /galaxy/lib/galaxy/dependencies/pinned-requirements.txt crypt4gh
fi
exec /venv-pulsar/bin/pulsar-serve /pulsar/config/server.ini
