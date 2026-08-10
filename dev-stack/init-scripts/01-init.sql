-- Supabase Local Setup - Database Initialization Script
-- This script runs automatically when PostgreSQL container starts for the first time
-- It sets up the necessary extensions, schemas, users, and tables for Supabase services

-- ============================================================================
-- SUPABASE ADMIN ROLE (Required by Supabase postgres image)
-- ============================================================================

-- Create supabase_admin role if it doesn't exist (required by supautils library)
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'supabase_admin') THEN
    CREATE ROLE supabase_admin WITH LOGIN SUPERUSER CREATEDB CREATEROLE REPLICATION BYPASSRLS;
  END IF;
END
$$;

-- ============================================================================
-- EXTENSIONS
-- ============================================================================

-- Enable UUID generation functions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enable cryptographic functions (used for password hashing, etc.)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- DATABASE USERS
-- ============================================================================

-- Create dedicated database user for Auth service (GoTrue)
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = 'supabase_auth_admin') THEN
    CREATE USER supabase_auth_admin WITH PASSWORD 'auth-admin-password';
  END IF;
END
$$;

-- Create dedicated database user for Storage service
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = 'supabase_storage_admin') THEN
    CREATE USER supabase_storage_admin WITH PASSWORD 'storage-admin-password';
  END IF;
END
$$;

-- Create dedicated database user for Realtime service
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = 'supabase_realtime_admin') THEN
    CREATE USER supabase_realtime_admin WITH PASSWORD 'realtime-admin-password';
  END IF;
END
$$;

-- ============================================================================
-- SCHEMAS
-- ============================================================================

-- Create auth schema for GoTrue authentication service
CREATE SCHEMA IF NOT EXISTS auth;

-- Create storage schema for Storage API
CREATE SCHEMA IF NOT EXISTS storage;

-- Create realtime schema for Realtime service
CREATE SCHEMA IF NOT EXISTS realtime;

-- Create _realtime schema for Realtime internal use
CREATE SCHEMA IF NOT EXISTS _realtime;

-- Set schema ownership to service users so they can run migrations
ALTER SCHEMA auth OWNER TO supabase_auth_admin;
ALTER SCHEMA storage OWNER TO supabase_storage_admin;
ALTER SCHEMA realtime OWNER TO supabase_realtime_admin;
ALTER SCHEMA _realtime OWNER TO supabase_realtime_admin;

-- ============================================================================
-- STORAGE TABLES
-- ============================================================================

-- Note: Storage service migrations have a bug where the initial migration
-- doesn't create tables properly but marks itself as complete. We need to
-- create the basic tables here so subsequent migrations can run.
CREATE TABLE IF NOT EXISTS storage.buckets (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  owner UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS storage.objects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bucket_id TEXT REFERENCES storage.buckets(id),
  name TEXT NOT NULL,
  owner UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  last_accessed_at TIMESTAMPTZ DEFAULT NOW(),
  metadata JSONB
);

-- Set ownership to storage admin user
ALTER TABLE storage.buckets OWNER TO supabase_storage_admin;
ALTER TABLE storage.objects OWNER TO supabase_storage_admin;

-- ============================================================================
-- REALTIME TABLES
-- ============================================================================

-- Note: Realtime tables are created by the Realtime service migrations
-- We only need to ensure the schemas exist and the user has proper permissions

-- Setup replication publication for realtime changes
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    CREATE PUBLICATION supabase_realtime FOR ALL TABLES;
  END IF;
END
$$;

-- ============================================================================
-- PERMISSIONS FOR POSTGRES USER
-- ============================================================================

-- Grant all privileges on schemas to postgres user (superuser)
GRANT ALL PRIVILEGES ON SCHEMA auth TO postgres;
GRANT ALL PRIVILEGES ON SCHEMA storage TO postgres;
GRANT ALL PRIVILEGES ON SCHEMA realtime TO postgres;
GRANT ALL PRIVILEGES ON SCHEMA _realtime TO postgres;

-- Grant all privileges on all tables in schemas to postgres user
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA auth TO postgres;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA storage TO postgres;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA realtime TO postgres;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA _realtime TO postgres;

-- Grant all privileges on all sequences in schemas to postgres user
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA auth TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA storage TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA realtime TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA _realtime TO postgres;

-- Set default privileges for future tables and sequences
ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT ALL PRIVILEGES ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES IN SCHEMA storage GRANT ALL PRIVILEGES ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES IN SCHEMA realtime GRANT ALL PRIVILEGES ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES IN SCHEMA _realtime GRANT ALL PRIVILEGES ON TABLES TO postgres;

ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT ALL PRIVILEGES ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES IN SCHEMA storage GRANT ALL PRIVILEGES ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES IN SCHEMA realtime GRANT ALL PRIVILEGES ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES IN SCHEMA _realtime GRANT ALL PRIVILEGES ON SEQUENCES TO postgres;

-- ============================================================================
-- PERMISSIONS FOR SERVICE USERS
-- ============================================================================

-- Auth user permissions: Full access to auth schema
GRANT ALL PRIVILEGES ON SCHEMA auth TO supabase_auth_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA auth TO supabase_auth_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA auth TO supabase_auth_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT ALL PRIVILEGES ON TABLES TO supabase_auth_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT ALL PRIVILEGES ON SEQUENCES TO supabase_auth_admin;

-- Storage user permissions: Full access to storage schema
GRANT ALL PRIVILEGES ON SCHEMA storage TO supabase_storage_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA storage TO supabase_storage_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA storage TO supabase_storage_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA storage GRANT ALL PRIVILEGES ON TABLES TO supabase_storage_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA storage GRANT ALL PRIVILEGES ON SEQUENCES TO supabase_storage_admin;

-- Realtime user permissions: SELECT on public schema, full access to realtime schemas
GRANT USAGE ON SCHEMA public TO supabase_realtime_admin;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO supabase_realtime_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO supabase_realtime_admin;

GRANT USAGE ON SCHEMA realtime TO supabase_realtime_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA realtime TO supabase_realtime_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA realtime TO supabase_realtime_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA realtime GRANT ALL PRIVILEGES ON TABLES TO supabase_realtime_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA realtime GRANT ALL PRIVILEGES ON SEQUENCES TO supabase_realtime_admin;

GRANT ALL PRIVILEGES ON SCHEMA _realtime TO supabase_realtime_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA _realtime TO supabase_realtime_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA _realtime TO supabase_realtime_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA _realtime GRANT ALL PRIVILEGES ON TABLES TO supabase_realtime_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA _realtime GRANT ALL PRIVILEGES ON SEQUENCES TO supabase_realtime_admin;

-- Grant replication permissions to realtime user
ALTER USER supabase_realtime_admin WITH REPLICATION;

