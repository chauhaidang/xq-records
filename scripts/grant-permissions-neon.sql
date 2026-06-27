-- Grant runtime database permissions to the xq-records application user.
--
-- Required psql variables:
--   app_user  Role name to grant permissions to, e.g. xq_records_app_user
--
-- Usage:
--   psql "$XQ_RECORDS_DATABASE_URL" \
--     -v ON_ERROR_STOP=1 \
--     -v app_user="xq_records_app_user" \
--     -f scripts/grant-permissions-neon.sql

\if :{?app_user}
\else
  \echo 'Missing required psql variable: app_user'
  \quit 1
\endif

GRANT USAGE ON SCHEMA public TO :"app_user";

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO :"app_user";
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO :"app_user";
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO :"app_user";

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO :"app_user";
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO :"app_user";
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT EXECUTE ON FUNCTIONS TO :"app_user";

SELECT
    'table' AS object_type,
    tablename AS object_name,
    has_table_privilege(:'app_user', format('%I.%I', schemaname, tablename), 'SELECT') AS can_select,
    has_table_privilege(:'app_user', format('%I.%I', schemaname, tablename), 'INSERT') AS can_insert,
    has_table_privilege(:'app_user', format('%I.%I', schemaname, tablename), 'UPDATE') AS can_update,
    has_table_privilege(:'app_user', format('%I.%I', schemaname, tablename), 'DELETE') AS can_delete
FROM pg_catalog.pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('object_types', 'objects', 'object_versions')
ORDER BY tablename;
