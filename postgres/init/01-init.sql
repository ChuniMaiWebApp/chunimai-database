-- Production database initialisation. Runs once, on an empty data volume.
--
-- Deliberately much smaller than dev-stack/init-scripts/01-init.sql. That file
-- also creates supabase_auth_admin, supabase_storage_admin and
-- supabase_realtime_admin with passwords written literally into the SQL
-- ('auth-admin-password' and friends). Those exist for GoTrue, Storage and
-- Realtime — none of which run in production — so carrying them over would put
-- three login roles with published passwords into the live database for no
-- reason at all.
--
-- What is left is what the supabase/postgres image and postgres-meta actually
-- need.

-- supautils, which the image preloads, expects this role to exist.
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'supabase_admin') THEN
    CREATE ROLE supabase_admin WITH LOGIN SUPERUSER CREATEDB CREATEROLE REPLICATION BYPASSRLS;
  END IF;
END
$$;

-- gen_random_uuid() is used by app.play_details and friends; pgcrypto also
-- backs the digest functions the migrations rely on.
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
