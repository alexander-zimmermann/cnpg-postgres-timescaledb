# syntax=docker/dockerfile:1.23
ARG PG_MAJOR=16
FROM ghcr.io/cloudnative-pg/postgresql:16.13

USER root

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# hadolint ignore=DL3008
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      gnupg \
      lsb-release \
 && curl -fsSL https://packagecloud.io/timescale/timescaledb/gpgkey \
      | gpg --dearmor -o /usr/share/keyrings/timescaledb.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/timescaledb.gpg] https://packagecloud.io/timescale/timescaledb/debian/ $(lsb_release -cs) main" \
      > /etc/apt/sources.list.d/timescaledb.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      "timescaledb-2-postgresql-${PG_MAJOR}=2.17.*" \
 && apt-get purge -y --auto-remove curl gnupg lsb-release \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

USER 26
