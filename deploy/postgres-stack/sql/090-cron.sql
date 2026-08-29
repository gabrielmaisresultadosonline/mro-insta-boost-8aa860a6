-- ============================================================
-- ZAPMRO — 9. CRON JOBS
-- Gerado em: 2026-08-29T14:18:03.232Z
-- ============================================================
BEGIN;
SET session_replication_role = replica;

SELECT cron.schedule('process-scheduled-flows-every-minute', '* * * * *', '
  SELECT net.http_post(
    url := ''https://aossudsganqiapcoqthe.supabase.co/functions/v1/meta-whatsapp-crm'',
    headers := ''{"Content-Type":"application/json","apikey":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFvc3N1ZHNnYW5xaWFwY29xdGhlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg2NjUyOTQsImV4cCI6MjA5NDI0MTI5NH0.iXRkC4lymM_vVOYI1Q2AfrXBxRa-9gTIpMX6jGVnCgQ","Authorization":"Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFvc3N1ZHNnYW5xaWFwY29xdGhlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg2NjUyOTQsImV4cCI6MjA5NDI0MTI5NH0.iXRkC4lymM_vVOYI1Q2AfrXBxRa-9gTIpMX6jGVnCgQ"}''::jsonb,
    body := jsonb_build_object(''action'',''processScheduled'',''source'',''cron'',''ts'', now()),
    timeout_milliseconds := 20000
  );
');
SELECT cron.schedule('process-countdown-triggers', '*/2 * * * *', '
  SELECT net.http_post(
    url := ''https://aossudsganqiapcoqthe.supabase.co/functions/v1/meta-whatsapp-crm'',
    headers := ''{"Content-Type":"application/json","apikey":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFvc3N1ZHNnYW5xaWFwY29xdGhlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg2NjUyOTQsImV4cCI6MjA5NDI0MTI5NH0.iXRkC4lymM_vVOYI1Q2AfrXBxRa-9gTIpMX6jGVnCgQ"}''::jsonb,
    body := ''{"action": "processCountdownTriggers"}''::jsonb,
    timeout_milliseconds := 20000
  );
');
SELECT cron.schedule('ai-recovery-every-10min', '*/10 * * * *', '
  SELECT net.http_post(
    url := ''https://aossudsganqiapcoqthe.supabase.co/functions/v1/meta-whatsapp-crm'',
    headers := ''{"Content-Type":"application/json","apikey":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFvc3N1ZHNnYW5xaWFwY29xdGhlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg2NjUyOTQsImV4cCI6MjA5NDI0MTI5NH0.iXRkC4lymM_vVOYI1Q2AfrXBxRa-9gTIpMX6jGVnCgQ"}''::jsonb,
    body := ''{"action": "processAiRecovery"}''::jsonb,
    timeout_milliseconds := 30000
  );
');
SELECT cron.schedule('cleanup-cron-and-net-logs', '17 4 * * *', '
  DELETE FROM cron.job_run_details WHERE end_time < now() - interval ''2 days'';
  DELETE FROM net._http_response WHERE created < now() - interval ''6 hours'';
');


SET session_replication_role = DEFAULT;
COMMIT;