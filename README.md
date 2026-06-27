# XQ Records Database

Prisma-owned PostgreSQL database module for the `xq-records` Neon database.

This module is separate from `database/`, which remains dedicated to the existing `xq_fitness` database.

## Target

| Item | Value |
| --- | --- |
| Neon project | `xq-records` |
| Database | `xq-records` |
| Schema | `public` |
| Local Docker image | `xq-records-db:latest` |

## Setup

```bash
npm install
cp .env.example .env
# Edit .env and replace <password> with the Neon password.
npm run prisma:validate
npm run prisma:generate
```

Do not commit `.env` or real connection strings.

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

## Docker

The local/test Docker image is initialized from checked-in Prisma migration SQL.

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

Default local connection:

```text
postgresql://xq_records_user:xq_records_password@localhost:5432/xq-records?schema=public
```

## Tests

```bash
npm run prisma:generate
npm run test:smoke
```

Smoke tests expect the schema to already exist. Use the Docker image for local verification or run Prisma migrations against a disposable Neon branch.
