#!/usr/bin/env bash
# restaurar.sh — carrega este pacote num novo banco PostgreSQL / Supabase
set -euo pipefail
: "${NEW_DB_URL:?defina NEW_DB_URL (string de conexão do destino)}"
echo "1) schema public + dados..."
psql "$NEW_DB_URL" -v ON_ERROR_STOP=0 -f 01_banco_public.sql
echo "2) extensions + cron..."
psql "$NEW_DB_URL" -v ON_ERROR_STOP=0 -f 04_extras.sql
echo "3) auth.users + identities..."
psql "$NEW_DB_URL" -v ON_ERROR_STOP=0 -f 02_auth.sql
echo "4) storage inventário (metadados)..."
psql "$NEW_DB_URL" -v ON_ERROR_STOP=0 -f 03_storage_inventario.sql
echo "OK. Binários do Storage: node restaurar-storage.mjs (com DESTINO_URL/DESTINO_KEY)."
