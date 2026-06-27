# XQ Records Database Container
FROM postgres:16-alpine

ENV POSTGRES_DB=xq-records
ENV POSTGRES_USER=xq_records_user
ENV POSTGRES_PASSWORD=xq_records_password

# Generated from prisma/migrations by scripts/prepare-docker-init.sh.
COPY docker-init/ /docker-entrypoint-initdb.d/

EXPOSE 5432

HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=3 \
  CMD pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB} || exit 1
