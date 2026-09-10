-- Run in an interactive DBA psql session connected to routemate_db.
-- Existing names deliberately fail for explicit review. No passwords in this file.
BEGIN;
CREATE ROLE routemate_api LOGIN INHERIT NOSUPERUSER NOBYPASSRLS
  NOCREATEDB NOCREATEROLE NOREPLICATION;
GRANT routemate_app TO routemate_api WITH INHERIT TRUE, SET FALSE;
GRANT CONNECT ON DATABASE routemate_db TO routemate_api;
CREATE ROLE routemate_platform_operator LOGIN NOINHERIT NOSUPERUSER NOBYPASSRLS
  NOCREATEDB NOCREATEROLE NOREPLICATION;
GRANT routemate_platform_admin TO routemate_platform_operator WITH INHERIT FALSE, SET TRUE;
GRANT CONNECT ON DATABASE routemate_db TO routemate_platform_operator;
COMMIT;
\password routemate_api
\password routemate_platform_operator
-- Keep routemate_app, routemate_platform_admin and routemate_auth_owner NOLOGIN.
