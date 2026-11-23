# syntax=docker/dockerfile:1.29
# standard = the old system image without in-core Barman; backups run through the barman-cloud plugin
FROM ghcr.io/cloudnative-pg/postgresql:18.7-standard-trixie

# ARG must be inside the build stage (after FROM); a top-level ARG is
# only available for the FROM line itself and would expand to "" in RUN.
ARG PG_MAJOR=18

USER root

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# The toolkit ships one versioned .so, so a new version needs ALTER EXTENSION timescaledb_toolkit UPDATE right after the roll
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
      "timescaledb-2-postgresql-${PG_MAJOR}=2.26.*" \
      "timescaledb-2-loader-postgresql-${PG_MAJOR}=2.26.*" \
      "timescaledb-toolkit-postgresql-${PG_MAJOR}=1:1.24.*" \
 && apt-get purge -y --auto-remove curl gnupg lsb-release \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

USER 26
