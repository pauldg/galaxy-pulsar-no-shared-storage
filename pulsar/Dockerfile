# Pulsar on its own filesystem: it sees the Galaxy checkout (read-only) but not Galaxy's object store.
FROM python:3.11-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential git curl \
    && rm -rf /var/lib/apt/lists/*
ARG PULSAR_VERSION=0.15.16
RUN python -m venv /venv-pulsar \
    && /venv-pulsar/bin/pip install --no-cache-dir "pulsar-app==${PULSAR_VERSION}" gunicorn
COPY app.yml server.ini /pulsar/config/
COPY entrypoint.sh /entrypoint.sh
ENV PULSAR_CONFIG_DIR=/pulsar/config \
    GALAXY_HOME=/galaxy \
    GALAXY_VIRTUAL_ENV=/venv-galaxy
EXPOSE 8913
ENTRYPOINT ["/entrypoint.sh"]
