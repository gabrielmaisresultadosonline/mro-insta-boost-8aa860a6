-- ============================================================
-- 085 - Garante uma configuração CRM por usuário
-- ------------------------------------------------------------
-- O Embedded Signup salva a conexão com ON CONFLICT (user_id).
-- Sem esta constraint o PostgreSQL rejeita a troca do código OAuth.
-- Idempotente e seguro para bases já migradas.
-- ============================================================

-- Mantém, para cada usuário, o registro com credenciais Meta mais completo e
-- recente. Registros sem usuário não participam da deduplicação.
WITH ranked AS (
  SELECT
    id,
    ROW_NUMBER() OVER (
      PARTITION BY user_id
      ORDER BY
        (meta_access_token IS NOT NULL)::int DESC,
        (meta_phone_number_id IS NOT NULL)::int DESC,
        (meta_waba_id IS NOT NULL)::int DESC,
        updated_at DESC NULLS LAST,
        created_at DESC NULLS LAST,
        id DESC
    ) AS rn
  FROM public.crm_settings
  WHERE user_id IS NOT NULL
)
DELETE FROM public.crm_settings settings
USING ranked
WHERE settings.id = ranked.id
  AND ranked.rn > 1;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.crm_settings'::regclass
      AND contype IN ('u', 'p')
      AND conkey = ARRAY[
        (SELECT attnum
         FROM pg_attribute
         WHERE attrelid = 'public.crm_settings'::regclass
           AND attname = 'user_id')
      ]::smallint[]
  ) THEN
    ALTER TABLE public.crm_settings
      ADD CONSTRAINT crm_settings_user_id_key UNIQUE (user_id);
  END IF;
END $$;
