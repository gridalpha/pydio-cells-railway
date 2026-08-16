# Pydio Cells on Railway

Thin wrapper around the official [`pydio/cells`](https://hub.docker.com/r/pydio/cells)
image that makes a one-click Railway deployment work unattended.

Cells only accepts its first-run configuration as a **file**
(`CELLS_INSTALL_YAML`), never as individual environment variables. This repo
exists so that descriptor lives in reviewable source rather than in a multi-line
Railway variable. `railway-entrypoint.sh` renders it from the service
environment on every boot, pins the site bind address to `$PORT`, derives the
public URL from `RAILWAY_PUBLIC_DOMAIN`, and then execs the upstream
entrypoint — which is what decides between `cells configure` (first boot) and
`cells start`.

## Variables

| Variable | Required | Default | Notes |
|---|---|---|---|
| `CELLS_ADMIN_PASSWORD` | yes | — | Password for the first administrator. |
| `DB_HOST` | yes | — | Reference the Postgres service. |
| `DB_PORT` | no | `5432` | |
| `DB_NAME` | no | `railway` | |
| `DB_USER` | no | `postgres` | |
| `DB_PASSWORD` | no | empty | |
| `MONGO_DSN` | no | unset | Full `mongodb://…` DSN. Unset keeps logs, activities, versions and the search index in embedded BoltDB/Bleve files on the volume. |
| `CELLS_ADMIN_LOGIN` | no | `admin` | |
| `CELLS_APPLICATION_TITLE` | no | `Pydio Cells` | |
| `CELLS_SITE_EXTERNAL` | no | `https://$RAILWAY_PUBLIC_DOMAIN` | Set only when fronting Cells with your own domain that Railway does not know about. |
| `CELLS_SITE_NO_TLS` | no | `1` | Railway terminates TLS at the edge. |
| `PORT` | no | `8080` | |

Cells stores its configuration, keyring and file datasources under
`/var/cells`, which must be a persistent volume.

Upstream project: <https://github.com/pydio/cells> (AGPL-3.0).
