#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-migrate}"

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required environment variable: ${name}"
    exit 1
  fi
}

verify_connection() {
  require_env DATABASE_URL

  echo "Testing Neon connection..."
  for attempt in 1 2 3; do
    if psql "$DATABASE_URL" -c "SELECT version();" >/dev/null 2>&1; then
      echo "Connected to Neon successfully"
      return 0
    fi

    echo "Connection attempt ${attempt} failed."
    if [[ "$attempt" -lt 3 ]]; then
      echo "Waiting before retry; Neon compute may be waking up."
      sleep 10
    fi
  done

  echo "Failed to connect to Neon database after 3 attempts."
  echo "Check DATABASE_URL, Neon branch/database state, IP allowlist, and SSL settings."
  exit 1
}

deploy_prisma_migrations() {
  echo "Validating Prisma schema..."
  npx prisma validate

  echo "Deploying Prisma migrations..."
  for attempt in 1 2 3; do
    set +e
    output="$(npx prisma migrate deploy 2>&1)"
    status=$?
    set -e

    echo "$output"

    if [[ "$status" -eq 0 ]]; then
      echo "Prisma migrations deployed successfully"
      return 0
    fi

    if ! grep -Eq "P1001|P1002|Can't reach|timeout|ECONNRESET|ECONNREFUSED" <<<"$output"; then
      echo "Prisma migration failed with a non-transient error."
      exit "$status"
    fi

    echo "Prisma migration connection attempt ${attempt} failed."
    if [[ "$attempt" -lt 3 ]]; then
      echo "Waiting before retry."
      sleep 15
    fi
  done

  echo "Prisma migration failed after 3 connection attempts."
  exit 1
}

verify_records_tables() {
  echo "Verifying records tables..."
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<'SQL'
DO $$
DECLARE
  table_count integer;
BEGIN
  SELECT COUNT(*)
  INTO table_count
  FROM information_schema.tables
  WHERE table_schema = 'public'
    AND table_name IN ('object_types', 'objects', 'object_versions');

  IF table_count <> 3 THEN
    RAISE EXCEPTION 'Expected 3 xq-records tables, found %', table_count;
  END IF;
END
$$;
SQL
}

use_migration_database_url() {
  if [[ -n "${MIGRATION_DATABASE_URL:-}" ]]; then
    echo "Using MIGRATION_DATABASE_URL for Prisma migration."
    export DATABASE_URL="$MIGRATION_DATABASE_URL"
  fi
}

create_app_user() {
  require_env DB_ADMIN_USER
  require_env DB_ADMIN_PASSWORD
  require_env APP_DB_USER
  require_env APP_DB_PASSWORD

  PGUSER="$DB_ADMIN_USER" PGPASSWORD="$DB_ADMIN_PASSWORD" psql "$DATABASE_URL" \
    -v ON_ERROR_STOP=1 \
    -v app_user="$APP_DB_USER" \
    -v app_password="$APP_DB_PASSWORD" \
    -f scripts/create-app-user-neon.sql
}

grant_app_permissions() {
  require_env DB_ADMIN_USER
  require_env DB_ADMIN_PASSWORD
  require_env APP_DB_USER

  PGUSER="$DB_ADMIN_USER" PGPASSWORD="$DB_ADMIN_PASSWORD" psql "$DATABASE_URL" \
    -v ON_ERROR_STOP=1 \
    -v app_user="$APP_DB_USER" \
    -f scripts/grant-permissions-neon.sql
}

case "$MODE" in
  migrate)
    use_migration_database_url
    verify_connection
    deploy_prisma_migrations
    verify_records_tables
    ;;
  create-user)
    verify_connection
    create_app_user
    ;;
  grant-permissions)
    verify_connection
    grant_app_permissions
    ;;
  setup-app-user)
    verify_connection
    create_app_user
    grant_app_permissions
    ;;
  *)
    echo "Unknown mode: ${MODE}"
    exit 1
    ;;
esac
