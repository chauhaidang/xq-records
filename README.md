# XQ Records Database

Prisma-owned PostgreSQL database module for the `xq-records` Neon database.

This module is separate from `database/`, which remains dedicated to the existing `xq_fitness` database.

## Target


| Item               | Value                                  |
| ------------------ | -------------------------------------- |
| Neon project       | `xq-records`                           |
| Database           | `xq-records`                           |
| Schema             | `public`                               |
| Local Docker image | `xq-records-db:latest`                 |


## Setup

```bash
npm install
cp .env.example .env
# Edit .env and replace <password> with the Neon password.
npm run prisma:validate
npm run prisma:generate
```

Do not commit `.env` or real connection strings.

## Schema

`xq-records` stores abstract business objects and their history. An object can
represent concepts from different domains, such as an exercise, routine, order,
or current asset.

```mermaid
erDiagram
    OBJECT_TYPES ||--o{ OBJECTS : defines
    OBJECTS ||--o{ OBJECT_VERSIONS : has_history
    OBJECTS o|--o| OBJECT_VERSIONS : current_version

    OBJECT_TYPES {
        string id PK
        string name UK
        string display_name
        string description
        json schema_json
        datetime created_at
        datetime updated_at
    }

    OBJECTS {
        string id PK
        string object_type_id FK
        string external_key
        string origin_source
        string status
        string current_version_id FK
        datetime created_at
        datetime updated_at
    }

    OBJECT_VERSIONS {
        string id PK
        string object_id FK
        int version
        json data
        string change_reason
        datetime valid_from
        datetime valid_to
        datetime created_at
    }
```



Key rules:

- `object_types.name` is unique.
- `objects.origin_source` is required so each object can trace back to where it came from.
- `objects` are unique by `(object_type_id, origin_source, external_key)`.
- `object_versions` are unique by `(object_id, version)`.
- Deleting an object deletes its version history.
- Deleting an object type is restricted while objects still use it.



## Prisma Migrations

Prisma is the source of truth for this database.

```bash
# Create/apply a development migration
npm run migrate:dev -- --name <migration-name>

# Apply checked-in migrations to production or CI
npm run migrate:deploy

# Inspect migration state
npm run migrate:status
```

Production should use `migrate deploy` with `XQ_RECORDS_DATABASE_URL`, not the fitness database `NEON_DATABASE_URL`.

## Application User

Production applications should not connect as `neondb_owner`. Use a restricted
application role instead.

Default role name:

```text
xq_records_app_user
```

Required GitHub secrets/variables:

```text
XQ_RECORDS_DATABASE_URL       # Neon connection string for xq-records
XQ_RECORDS_DB_ADMIN_USER      # Neon admin/owner role used for psql setup steps
XQ_RECORD_DB_ADMIN_PW         # Neon admin/owner password used for psql setup steps
XQ_RECORDS_APP_DB_PASSWORD    # password for the restricted app role
XQ_RECORDS_APP_DB_USER        # optional GitHub variable, defaults to xq_records_app_user
```

Keep `XQ_RECORDS_APP_DB_PASSWORD` separate from `XQ_RECORD_DB_ADMIN_PW`.
The application role should not share the admin password.

Manual workflow modes in `migrate-to-neon.yml`:

```text
migrate             # npx prisma migrate deploy
create-user         # create/update the restricted app role and password
grant-permissions   # grant runtime permissions on public schema objects
setup-app-user      # create-user + grant-permissions
```

Local command shape:

```bash
PGUSER="$XQ_RECORDS_DB_ADMIN_USER" \
PGPASSWORD="$XQ_RECORD_DB_ADMIN_PW" \
psql "$XQ_RECORDS_DATABASE_URL" \
  -v ON_ERROR_STOP=1 \
  -v app_user="xq_records_app_user" \
  -v app_password="$XQ_RECORDS_APP_DB_PASSWORD" \
  -f scripts/create-app-user-neon.sql

PGUSER="$XQ_RECORDS_DB_ADMIN_USER" \
PGPASSWORD="$XQ_RECORD_DB_ADMIN_PW" \
psql "$XQ_RECORDS_DATABASE_URL" \
  -v ON_ERROR_STOP=1 \
  -v app_user="xq_records_app_user" \
  -f scripts/grant-permissions-neon.sql
```

The app role receives `CONNECT`, `USAGE` on `public`, and
`SELECT/INSERT/UPDATE/DELETE` on the records tables. It does not receive DDL or
role-management permissions.

## Docker

The local/test Docker image is initialized from checked-in Prisma migration SQL,
then runs the same application-user setup steps as CI (`create-user` +
`grant-permissions`).

```bash
npm run docker:prepare
npm run docker:build
```

Run locally:

```bash
docker run --rm \
  --name xq-records-db \
  -p 5432:5432 \
  xq-records-db:latest
```

Default local connections:

```text
# Admin/bootstrap role (migrations and local smoke tests)
postgresql://xq_records_user:xq_records_password@localhost:5432/xq-records?schema=public

# Restricted application role (mirrors production app access)
postgresql://xq_records_app_user:xq_records_app_password@localhost:5432/xq-records?schema=public
```

Override the app role at runtime with `POSTGRES_APP_USER` and
`POSTGRES_APP_PASSWORD`.



## Test Environment

This module includes an `xq-infra` test environment under `test-env/`.

```bash
npm run docker:build
xq-infra generate -f ./test-env
xq-infra up
```

The test environment starts the local `xq-records-db:latest` image with:

```text
POSTGRES_DB=xq-records
POSTGRES_USER=xq_records_user
POSTGRES_PASSWORD=xq_records_password
POSTGRES_APP_USER=xq_records_app_user
POSTGRES_APP_PASSWORD=xq_records_app_password
```

Run smoke tests against it with:

```bash
DATABASE_URL='postgresql://xq_records_user:xq_records_password@localhost:5432/xq-records?schema=public' npm run test:smoke
```

When finished:

```bash
xq-infra down
```



## Tests

```bash
npm run prisma:generate
npm run test:smoke
```

Smoke tests expect the schema to already exist. Use the Docker image for local verification or run Prisma migrations against a disposable Neon branch.
