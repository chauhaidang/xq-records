-- Create or update the restricted application user for the xq-records Neon database.
--
-- Required psql variables:
--   app_user      Role name to create/update, e.g. xq_records_app_user
--   app_password  Secure password for the application role
--
-- Usage:
--   psql "$XQ_RECORDS_DATABASE_URL" \
--     -v ON_ERROR_STOP=1 \
--     -v app_user="xq_records_app_user" \
--     -v app_password="$XQ_RECORDS_APP_DB_PASSWORD" \
--     -f scripts/create-app-user-neon.sql

\if :{?app_user}
\else
  \echo 'Missing required psql variable: app_user'
  \quit 1
\endif

\if :{?app_password}
\else
  \echo 'Missing required psql variable: app_password'
  \quit 1
\endif

SELECT format('CREATE ROLE %I LOGIN', :'app_user')
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_roles
    WHERE rolname = :'app_user'
);
\gexec

SELECT format(
    'ALTER ROLE %I WITH LOGIN PASSWORD %L',
    :'app_user',
    :'app_password'
);
\gexec

SELECT format('GRANT CONNECT ON DATABASE %I TO %I', current_database(), :'app_user');
\gexec

SELECT
    rolname AS username,
    rolcanlogin AS can_login,
    rolcreatedb AS can_create_db,
    rolcreaterole AS can_create_role,
    rolsuper AS is_superuser
FROM pg_catalog.pg_roles
WHERE rolname = :'app_user';
