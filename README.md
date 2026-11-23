# cnpg-postgres-timescaledb

PostgreSQL container image for [CloudNativePG](https://cloudnative-pg.io/) with the [TimescaleDB](https://github.com/timescale/timescaledb) extension preinstalled.

## What it does

Extends the `standard` flavor of the official `ghcr.io/cloudnative-pg/postgresql` image (Debian trixie) with the `timescaledb-2-postgresql-${PG_MAJOR}` and `timescaledb-toolkit-postgresql-${PG_MAJOR}` apt packages from Timescale's [packagecloud](https://packagecloud.io/timescale/timescaledb) repository, so the image is a drop-in `imageName:` value for a CNPG `Cluster` resource. The `standard` flavor has no `barman-cloud` binaries; backups run through the [Barman Cloud plugin](https://github.com/cloudnative-pg/plugin-barman-cloud).

The TimescaleDB shared library still has to be loaded by the cluster — set it in `spec.postgresql.parameters`:

```yaml
postgresql:
  parameters:
    shared_preload_libraries: "timescaledb"
```

## Image

Published to `ghcr.io/alexander-zimmermann/cnpg-postgres-timescaledb`. Built for `linux/amd64` and `linux/arm64`.

Tag scheme: `<pg-version>-ts<ts-version>-tk` (e.g. `18.7-ts2.26-tk`). The tag carries neither the flavor nor the Debian release of the base image. The release workflow builds and pushes whenever a tag matching `*-ts*` lands. The `latest` tag tracks the most recent build from `main`.

The image's `ARG PG_MAJOR`, the `FROM` tag and the TimescaleDB apt pin must stay in sync — see the next section.

## Versioning policy

- **Patch / minor of the CNPG base image** (e.g. `18.7 → 18.8`) is bumped automatically by Renovate. It keeps the flavor and Debian suffix (`-standard-trixie`) and ignores the timestamped tags.
- **The toolkit is pinned** (`timescaledb-toolkit-postgresql-${PG_MAJOR}=1:<X.Y>.*`). Its package ships a single versioned `.so`, so every toolkit function fails after a roll to a different version until `ALTER EXTENSION timescaledb_toolkit UPDATE` runs in the database.
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
  imageName: ghcr.io/alexander-zimmermann/cnpg-postgres-timescaledb:18.7-ts2.26-tk
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
2. Open a PR. The `image` check builds the image and checks that TimescaleDB and the toolkit are installed.
3. After the merge, `Auto Tag` derives `<pg>-ts<ts>-tk` from the `Dockerfile` and pushes the tag if it is new. A `Dockerfile` change that keeps the Postgres and TimescaleDB versions produces no new tag.
4. The `Release` workflow builds and pushes both architecture-specific images and updates `:latest`.

## License

GPL-2.0-or-later — see [LICENSE](LICENSE).
