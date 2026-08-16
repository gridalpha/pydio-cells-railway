#!/bin/sh
#
# Renders Pydio Cells' headless install descriptor from the service environment,
# pins the site bind/external URL to what Railway actually serves, then hands
# over to the image's own entrypoint.
#
# Cells only accepts its install configuration as a YAML/JSON *file*
# (CELLS_INSTALL_YAML), so the descriptor is generated here rather than carried
# as a multi-line Railway variable.

set -eu

PORT="${PORT:-8080}"

# Railway terminates TLS at the edge and speaks plain HTTP to the container, so
# the internal Caddy site must not try to serve a certificate of its own.
CELLS_BIND="0.0.0.0:${PORT}"
CELLS_SITE_BIND="${CELLS_BIND}"
CELLS_SITE_NO_TLS="${CELLS_SITE_NO_TLS:-1}"
export CELLS_BIND CELLS_SITE_BIND CELLS_SITE_NO_TLS

# The public URL ends up in share links, OIDC issuers and password-reset mails.
if [ -z "${CELLS_SITE_EXTERNAL:-}" ] && [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
    CELLS_SITE_EXTERNAL="https://${RAILWAY_PUBLIC_DOMAIN}"
    export CELLS_SITE_EXTERNAL
fi

# Logs belong on stdout where Railway can read them; the volume is for user data.
CELLS_LOG_TO_FILE="${CELLS_LOG_TO_FILE:-false}"
export CELLS_LOG_TO_FILE

CELLS_INSTALL_YAML="${CELLS_INSTALL_YAML:-/tmp/cells-install.yml}"
export CELLS_INSTALL_YAML

fail() {
    echo "railway-entrypoint: $1" >&2
    exit 1
}

[ -n "${DB_HOST:-}" ] || fail "DB_HOST is required — reference the Postgres service"
[ -n "${CELLS_ADMIN_PASSWORD:-}" ] || fail "CELLS_ADMIN_PASSWORD is required"

# Escape for a YAML double-quoted scalar, so a password containing a quote or a
# backslash cannot break the descriptor.
yaml_escape() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

# The descriptor holds the first-admin password, so it is written outside the
# volume and regenerated from the environment on every boot.
umask 077
{
    printf 'frontendlogin: "%s"\n' "$(yaml_escape "${CELLS_ADMIN_LOGIN:-admin}")"
    printf 'frontendpassword: "%s"\n' "$(yaml_escape "$CELLS_ADMIN_PASSWORD")"
    printf 'frontendrepeatpassword: "%s"\n' "$(yaml_escape "$CELLS_ADMIN_PASSWORD")"
    printf 'frontendapplicationtitle: "%s"\n' "$(yaml_escape "${CELLS_APPLICATION_TITLE:-Pydio Cells}")"

    # pg_tcp makes Cells build the DSN itself, including the {{.Meta.*}} template
    # parameters it needs — a manual DSN would have to reproduce them by hand.
    printf 'dbconnectiontype: pg_tcp\n'
    printf 'dbtcphostname: "%s"\n' "$(yaml_escape "$DB_HOST")"
    printf 'dbtcpport: "%s"\n' "$(yaml_escape "${DB_PORT:-5432}")"
    printf 'dbtcpname: "%s"\n' "$(yaml_escape "${DB_NAME:-railway}")"
    printf 'dbtcpuser: "%s"\n' "$(yaml_escape "${DB_USER:-postgres}")"
    printf 'dbtcppassword: "%s"\n' "$(yaml_escape "${DB_PASSWORD:-}")"

    # Files live on the attached volume under $CELLS_DATA_DIR.
    printf 'dstype: FS\n'

    # Without a documents DSN, Cells keeps logs, activities, versions and the
    # search index in embedded BoltDB/Bleve files.
    if [ -n "${MONGO_DSN:-}" ]; then
        printf 'usedocumentsdsn: true\n'
        printf 'documentsdsn: "%s"\n' "$(yaml_escape "$MONGO_DSN")"
    fi
} > "$CELLS_INSTALL_YAML"

echo "railway-entrypoint: site ${CELLS_SITE_BIND} external=${CELLS_SITE_EXTERNAL:-<unset>} mongo=$([ -n "${MONGO_DSN:-}" ] && echo on || echo off)"

exec docker-entrypoint.sh "$@"
