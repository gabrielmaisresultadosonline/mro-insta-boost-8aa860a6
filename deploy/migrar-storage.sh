#!/usr/bin/env bash
# =============================================================================
#  migrar-storage.sh
#
#  Traz os ARQUIVOS (binários) do Storage da nuvem para a stack da VPS.
#  - Lista buckets/objetos pela função exportar-storage-vps (protegida por senha)
#  - Baixa cada arquivo pela URL pública da nuvem
#  - Envia para a stack local com upsert (idempotente: pode rodar quantas vezes
#    quiser, nada é apagado nem duplicado)
#
#      cd /var/www/ia-mro && ./deploy/migrar-storage.sh
# =============================================================================
set -Eeuo pipefail

C_R='\033[0;31m'; C_G='\033[0;32m'; C_Y='\033[1;33m'; C_C='\033[0;36m'; N='\033[0m'
ok()   { echo -e "${C_G}✔${N} $*"; }
info() { echo -e "  $*"; }
warn() { echo -e "${C_Y}!${N} $*"; }
err()  { echo -e "${C_R}✘${N} $*" >&2; }
sec()  { echo; echo -e "${C_C}══════ $* ══════${N}"; }
die()  { err "$*"; exit 1; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STACK="$ROOT/deploy/postgres-stack"

[ -f "$STACK/.env" ] || die "não achei $STACK/.env — rode ./deploy/atualizar.sh primeiro"
set -a; . "$STACK/.env"; set +a

command -v node >/dev/null 2>&1 || die "node não instalado (apt-get install -y nodejs)"

export CLOUD_URL="${CLOUD_URL:-https://aossudsganqiapcoqthe.supabase.co}"
export CLOUD_ANON="${CLOUD_ANON:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFvc3N1ZHNnYW5xaWFwY29xdGhlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg2NjUyOTQsImV4cCI6MjA5NDI0MTI5NH0.iXRkC4lymM_vVOYI1Q2AfrXBxRa-9gTIpMX6jGVnCgQ}"
export ADMIN_PASSWORD="${ADMIN_PASSWORD:-Ga145523@}"
export LOCAL_URL="${LOCAL_URL:-http://127.0.0.1:${GATEWAY_PORT:-8000}}"
export LOCAL_SERVICE_KEY="${SERVICE_ROLE_KEY:?SERVICE_ROLE_KEY ausente no .env da stack}"
export CONCURRENCY="${CONCURRENCY:-4}"   # baixo para não tomar 429 da nuvem
export RETRIES="${RETRIES:-5}"

sec "Esperando a stack local responder"
for i in $(seq 1 60); do
  curl -sf -o /dev/null "$LOCAL_URL/storage/v1/bucket" -H "Authorization: Bearer $LOCAL_SERVICE_KEY" -H "apikey: $LOCAL_SERVICE_KEY" && break
  sleep 2
done
ok "storage local respondendo"

sec "Copiando arquivos (nuvem → VPS)"
node "$ROOT/deploy/postgres-stack/scripts/copiar-storage.mjs"

sec "Conferência final"
curl -s "$LOCAL_URL/storage/v1/bucket" \
  -H "Authorization: Bearer $LOCAL_SERVICE_KEY" -H "apikey: $LOCAL_SERVICE_KEY" \
  | head -c 2000
echo
ok "Migração do Storage finalizada."
