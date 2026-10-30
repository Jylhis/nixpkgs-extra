#!/usr/bin/env bash
# Postgres + ClickHouse migrations, as upstream web/entrypoint.sh runs them
# before starting the web server. Expects DATABASE_URL (or DIRECT_URL),
# CLICKHOUSE_URL, CLICKHOUSE_MIGRATION_URL, CLICKHOUSE_USER and
# CLICKHOUSE_PASSWORD in the environment.
set -euo pipefail

: "${LANGFUSE_MIGRATIONS:?}"
export DIRECT_URL="${DIRECT_URL:-${DATABASE_URL:?}}"

prisma db execute --url "$DIRECT_URL" --file "$LANGFUSE_MIGRATIONS/cleanup.sql"
prisma migrate deploy --schema="$LANGFUSE_MIGRATIONS/prisma/schema.prisma"

# up.sh resolves its migration directories relative to itself.
bash "$LANGFUSE_MIGRATIONS/clickhouse/scripts/up.sh"
