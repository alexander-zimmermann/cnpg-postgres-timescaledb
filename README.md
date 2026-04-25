# cnpg-postgres-timescaledb

PostgreSQL container image for [CloudNativePG](https://cloudnative-pg.io/) with the [TimescaleDB](https://github.com/timescale/timescaledb) extension preinstalled.

## What it does

Extends the official `ghcr.io/cloudnative-pg/postgresql` image with the `timescaledb-2-postgresql-${PG_MAJOR}` apt package from Timescale's [packagecloud](https://packagecloud.io/timescale/timescaledb) repository. All CloudNativePG-specific tooling (`barman-cloud`, `pg_rewind`, the operator's bootstrap helpers) stays intact, so the image is a drop-in `imageName:` value for a CNPG `Cluster` resource.

The TimescaleDB shared library still has to be loaded by the cluster — set it in `spec.postgresql.parameters`:

```yaml
postgresql:
  parameters:
    shared_preload_libraries: "timescaledb"
```

## Image

Published to `ghcr.io/alexander-zimmermann/cnpg-postgres-timescaledb`. Built for `linux/amd64` and `linux/arm64`.

Tag scheme: `<pg-version>-ts<ts-version>` (e.g. `18.3-ts2.23`). Pushed by the release workflow whenever a tag matching `*-ts*` lands on `main`. The `latest` tag tracks the most recent build from `main`.

The image's `ARG PG_MAJOR`, the `FROM` tag and the TimescaleDB apt pin must stay in sync — see the next section.

## Versioning policy

- **Patch / minor of the CNPG base image** (e.g. `18.3 → 18.4`) is bumped automatically by Renovate.
- **Major of the CNPG base image** (e.g. `18.x → 19.x`) is **blocked in `.renovaterc.json5`** and has to be done manually. A major Postgres bump always implies:
  1. Update `FROM ghcr.io/cloudnative-pg/postgresql:<new>` (the only line Renovate touches).
  2. Update `ARG PG_MAJOR=<new>` so the apt-package name resolves correctly.
  3. Verify the matching TimescaleDB apt-package version (`timescaledb-2-postgresql-${PG_MAJOR}=<X.Y>.*`) exists for that PG major and bump it.
  4. Tag a new release `<new-pg>-ts<new-ts>` so the release workflow rebuilds.
- **TimescaleDB extension upgrades** also need a manual decision (no Renovate manager for the apt-package version pin). After bumping, run `ALTER EXTENSION timescaledb UPDATE` inside each CNPG cluster that already runs an older TimescaleDB.

## Usage in a CNPG `Cluster`

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: timescaledb-db
spec:
  imageName: ghcr.io/alexander-zimmermann/cnpg-postgres-timescaledb:18.3-ts2.23
  instances: 1
  postgresql:
    parameters:
      shared_preload_libraries: "timescaledb"
      max_worker_processes: "16"
      timescaledb.max_background_workers: "8"
  bootstrap:
    initdb:
      database: homelab
      owner: homelab
      postInitApplicationSQLRefs:
        configMapRefs:
          - name: timescaledb-bootstrap-sql
            key: bootstrap.sql
```

The bootstrap SQL is responsible for `CREATE EXTENSION IF NOT EXISTS timescaledb;` plus any hypertables / continuous aggregates. CNPG runs it once on initial cluster creation; later changes to the ConfigMap don't re-execute. Use a migration `Job` (or manual `psql`) for schema evolution and mirror the change back into the ConfigMap so a cluster rebuild lands at the same schema.

## Building locally

```sh
docker build -t cnpg-postgres-timescaledb:dev .
docker run --rm -e POSTGRES_PASSWORD=test cnpg-postgres-timescaledb:dev \
  postgres -c shared_preload_libraries=timescaledb &
sleep 5
docker exec $(docker ps -lq) psql -U postgres -c "CREATE EXTENSION timescaledb;" \
  -c "SELECT extversion FROM pg_extension WHERE extname='timescaledb';"
```

## Release process

1. Edit `Dockerfile` — adjust `FROM`, `ARG PG_MAJOR`, the TimescaleDB pin together.
2. Open a PR. CI runs `pre-commit` (hadolint, actionlint, gitleaks, …).
3. After merge, tag `<pg>-ts<ts>` on `main`:
   ```sh
   git tag -a 18.3-ts2.23 -m "Release 18.3-ts2.23: PostgreSQL 18.3 + TimescaleDB 2.23"
   git push origin 18.3-ts2.23
   ```
4. The `Release` workflow builds and pushes both architecture-specific images and updates `:latest`.

## License

GPL-2.0-or-later — see [LICENSE](LICENSE).
