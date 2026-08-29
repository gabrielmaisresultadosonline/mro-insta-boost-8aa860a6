-- ============================================================
-- 04_extras.sql — extensões e jobs do pg_cron (fora do public)
-- gerado em 2026-08-29T13:14:49Z
-- ============================================================

-- EXTENSIONS
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS supabase_vault WITH SCHEMA vault;
CREATE EXTENSION IF NOT EXISTS uuid-ossp WITH SCHEMA extensions;

-- PG_CRON JOBS
-- (erro ao ler cron.job)
