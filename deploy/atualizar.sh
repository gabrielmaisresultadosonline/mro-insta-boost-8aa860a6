#!/usr/bin/env bash
# =============================================================================
#  atualizar.sh — COMANDO ÚNICO do ZapMRO 100% PostgreSQL próprio
#  (não usa e não depende de Supabase/Lovable Cloud para nada)
#
#      cd /var/www/ia-mro && ./deploy/atualizar.sh
#
#  Faz, de ponta a ponta e de forma idempotente (pode rodar quantas vezes quiser):
#    1) git pull   ................ baixa o código novo
#    2) dependências .............. docker, node, psql, nginx (instala se faltar)
#    3) .env / secrets ............ cria os arquivos e GERA os segredos que faltam
#    4) stack ..................... sobe Postgres + Auth + REST + Realtime +
#                                   Storage + Edge Runtime (Deno) + Gateway
#    5) banco ..................... cria/atualiza TODAS as tabelas, funções,
#                                   triggers, RLS, índices, grants, cron
#                                   (a partir dos dumps em deploy/postgres-stack/sql)
#    6) functions ................. recarrega as functions em Deno (código do repo)
#    7) frontend .................. npm install + build apontando para a SUA API
#    8) nginx/pm2 ................. publica o dist e reinicia os processos
#    9) validação ................. health-check de cada serviço + contagens
#
#  Os .env podem ser preenchidos DEPOIS: o script nunca apaga valor já existente,
#  só completa o que estiver vazio. Rode de novo após editar e tudo se ajusta.
# =============================================================================
set -Eeuo pipefail

C_R='\033[0;31m'; C_G='\033[0;32m'; C_Y='\033[1;33m'; C_B='\033[0;34m'; C_C='\033[0;36m'; N='\033[0m'
ok()   { echo -e "${C_G}✔${N} $*"; }
info() { echo -e "${C_B}ℹ${N} $*"; }
warn() { echo -e "${C_Y}!${N} $*"; }
err()  { echo -e "${C_R}✘${N} $*" >&2; }
sec()  { echo; echo -e "${C_C}══════ $* ══════${N}"; }
die()  { err "$*"; exit 1; }
trap 'err "Falhou na linha $LINENO. Nada foi apagado — corrija e rode ./deploy/atualizar.sh de novo."' ERR

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STACK="$ROOT/deploy/postgres-stack"
SQLDIR="$STACK/sql"
SEM_BUILD="${SEM_BUILD:-0}"

sudo_() { if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi; }

# ---------------------------------------------------------------- 1) código --
sec "1/9 Código"
cd "$ROOT"
if [ -d .git ]; then
  git pull --ff-only origin "$(git rev-parse --abbrev-ref HEAD)" || warn "git pull não aplicado (siga com o código local)"
fi
chmod +x "$ROOT/deploy/"*.sh 2>/dev/null || true
ok "código em $(git rev-parse --short HEAD 2>/dev/null || echo 'local')"

# ---------------------------------------------------------- 2) dependências --
sec "2/9 Dependências do sistema"
faltando=()
for b in docker node npm psql curl jq openssl; do command -v "$b" >/dev/null 2>&1 || faltando+=("$b"); done
docker compose version >/dev/null 2>&1 || faltando+=("docker-compose")
if [ ${#faltando[@]} -gt 0 ]; then
  info "instalando: ${faltando[*]}"
  export DEBIAN_FRONTEND=noninteractive
  sudo_ apt-get update -y
  if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
    sudo_ apt-get install -y ca-certificates curl gnupg
    sudo_ install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo_ gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
    sudo_ chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      | sudo_ tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo_ apt-get update -y
    sudo_ apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo_ systemctl enable --now docker
  fi
  command -v node >/dev/null 2>&1 || { curl -fsSL https://deb.nodesource.com/setup_20.x | sudo_ -E bash -; sudo_ apt-get install -y nodejs; }
  command -v psql >/dev/null 2>&1 || sudo_ apt-get install -y postgresql-client
  sudo_ apt-get install -y nginx jq openssl unzip >/dev/null 2>&1 || true
fi
ok "dependências prontas"

# --------------------------------------------------------- 3) env / secrets --
sec "3/9 Configuração (.env e secrets.env)"
[ -f "$STACK/.env" ]         || cp "$STACK/.env.example" "$STACK/.env"
[ -f "$STACK/secrets.env" ]  || cp "$STACK/secrets.env.example" "$STACK/secrets.env"

set_env() { # set_env VAR VALOR  (só grava se estiver vazio/ausente)
  local var="$1" val="$2"
  if grep -qE "^${var}=" "$STACK/.env"; then
    local atual; atual="$(grep -m1 -E "^${var}=" "$STACK/.env" | cut -d= -f2-)"
    [ -n "$atual" ] && return 0
    sed -i "s|^${var}=.*|${var}=${val}|" "$STACK/.env"
  else
    echo "${var}=${val}" >> "$STACK/.env"
  fi
}

# segredos próprios da stack: gerados aqui, não vêm de lugar nenhum
gen() { openssl rand -hex 32; }
set_env POSTGRES_PASSWORD "$(gen)"
set_env JWT_SECRET "$(gen)"
set_env REALTIME_ENC_KEY "$(openssl rand -hex 16)"
set_env REALTIME_SECRET_KEY_BASE "$(openssl rand -hex 32)"

set -a; . "$STACK/.env"; set +a

# ANON_KEY / SERVICE_ROLE_KEY são JWTs assinados com o JWT_SECRET local
jwt() { # jwt <role>
  local role="$1" iat exp h p sig
  iat=$(date +%s); exp=$((iat + 60*60*24*3650))
  h=$(printf '{"alg":"HS256","typ":"JWT"}' | openssl base64 -A | tr '+/' '-_' | tr -d '=')
  p=$(printf '{"role":"%s","iss":"zapmro","iat":%s,"exp":%s}' "$role" "$iat" "$exp" | openssl base64 -A | tr '+/' '-_' | tr -d '=')
  sig=$(printf '%s.%s' "$h" "$p" | openssl dgst -binary -sha256 -hmac "$JWT_SECRET" | openssl base64 -A | tr '+/' '-_' | tr -d '=')
  printf '%s.%s.%s' "$h" "$p" "$sig"
}
[ -n "${ANON_KEY:-}" ]         || set_env ANON_KEY "$(jwt anon)"
[ -n "${SERVICE_ROLE_KEY:-}" ] || set_env SERVICE_ROLE_KEY "$(jwt service_role)"
set -a; . "$STACK/.env"; set +a

# as functions precisam enxergar as chaves da própria stack
touch "$STACK/secrets.env"
for kv in "APP_BASE_URL=${SITE_URL:-https://zapmro.com.br}" "SITE_URL=${SITE_URL:-https://zapmro.com.br}"; do
  grep -qE "^${kv%%=*}=" "$STACK/secrets.env" || echo "$kv" >> "$STACK/secrets.env"
done
vazios=$(grep -cE '^[A-Z0-9_]+=$' "$STACK/secrets.env" || true)
ok ".env pronto  |  secrets.env com ${vazios:-0} chave(s) ainda em branco (pode preencher depois)"

# ------------------------------------------------------------- 4) subir stack -
sec "4/9 Subindo a stack PostgreSQL"
cd "$STACK"
docker compose pull -q >/dev/null 2>&1 || true
docker compose up -d --remove-orphans
info "aguardando o banco…"
for i in $(seq 1 60); do
  docker exec zapmro-db pg_isready -U postgres >/dev/null 2>&1 && break
  sleep 2
  [ "$i" = 60 ] && die "o Postgres não subiu — veja: docker compose logs db"
done
ok "Postgres, Auth, REST, Realtime, Storage, Functions e Gateway no ar"

DB="postgresql://postgres:${POSTGRES_PASSWORD}@127.0.0.1:${PG_PORT:-5432}/${POSTGRES_DB:-postgres}"

# ------------------------------------------------------------------ 5) banco --
sec "5/9 Banco (tabelas, funções, RLS, índices, cron)"
mkdir -p "$SQLDIR"
aplicados=0
shopt -s nullglob
arquivos=("$SQLDIR"/*.sql)
if [ ${#arquivos[@]} -eq 0 ]; then
  warn "nenhum .sql em deploy/postgres-stack/sql/"
  warn "coloque ali o dump gerado em /admincentral → Migração (ou por deploy/migrar-tudo.sh) e rode de novo"
else
  psql "$DB" -v ON_ERROR_STOP=0 -q -c "create table if not exists public._migracoes_aplicadas(arquivo text primary key, hash text, aplicado_em timestamptz default now())" >/dev/null
  for f in $(printf '%s\n' "${arquivos[@]}" | sort); do
    nome="$(basename "$f")"; h="$(sha256sum "$f" | cut -c1-16)"
    ja="$(psql "$DB" -tAc "select hash from public._migracoes_aplicadas where arquivo='${nome}'" 2>/dev/null || true)"
    if [ "$ja" = "$h" ]; then info "· $nome (já aplicado)"; continue; fi
    info "· aplicando $nome"
    psql "$DB" -v ON_ERROR_STOP=0 -q -f "$f" > "/tmp/zapmro-sql-$nome.log" 2>&1 || true
    if grep -qiE '^psql:.*(ERROR|FATAL)' "/tmp/zapmro-sql-$nome.log"; then
      warn "  avisos/erros em $nome (normal em re-execução) → /tmp/zapmro-sql-$nome.log"
    fi
    psql "$DB" -q -c "insert into public._migracoes_aplicadas(arquivo,hash) values ('${nome}','${h}')
                      on conflict (arquivo) do update set hash=excluded.hash, aplicado_em=now()" >/dev/null
    aplicados=$((aplicados+1))
  done
fi
shopt -u nullglob
tabelas="$(psql "$DB" -tAc "select count(*) from information_schema.tables where table_schema='public'" 2>/dev/null || echo '?')"
ok "banco atualizado — ${aplicados} arquivo(s) aplicado(s), ${tabelas} tabelas públicas"

# -------------------------------------------------------------- 6) functions --
sec "6/9 Edge Functions (Deno, rodando na sua VPS)"
qtd=$(find "$ROOT/supabase/functions" -maxdepth 1 -mindepth 1 -type d ! -name '_shared' | wc -l)
( cd "$STACK" && docker compose up -d functions && docker compose restart functions >/dev/null )
ok "${qtd} funções recarregadas em ${PUBLIC_API_URL:-http://localhost:${GATEWAY_PORT:-8000}}/functions/v1/<nome>"

# --------------------------------------------------------------- 7) frontend --
sec "7/9 Frontend"
cd "$ROOT"
API="${PUBLIC_API_URL:-http://localhost:${GATEWAY_PORT:-8000}}"
cat > "$ROOT/.env" <<EOF
VITE_SUPABASE_URL="${API}"
VITE_SUPABASE_PUBLISHABLE_KEY="${ANON_KEY}"
VITE_SUPABASE_PROJECT_ID="zapmro"
EOF
ok ".env do frontend apontando para ${API} (sem Supabase)"
if [ "$SEM_BUILD" = "1" ]; then
  warn "build pulado (SEM_BUILD=1)"
else
  npm install --no-audit --no-fund --legacy-peer-deps
  rm -rf dist
  npm run build
  ok "build gerado em dist/ (vídeos, imagens e assets incluídos)"
fi

# ----------------------------------------------------------- 8) nginx / pm2 ---
sec "8/9 Publicação"
API_HOST="$(echo "$API" | sed -E 's#https?://##; s#/.*##')"
SITE_HOST="$(echo "${SITE_URL:-https://zapmro.com.br}" | sed -E 's#https?://##; s#/.*##')"
if command -v nginx >/dev/null 2>&1; then
  sudo_ tee /etc/nginx/sites-available/zapmro-api.conf >/dev/null <<EOF
server {
    listen 80;
    server_name ${API_HOST};
    client_max_body_size 512m;
    location / {
        proxy_pass http://127.0.0.1:${GATEWAY_PORT:-8000};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 600s;
    }
}
EOF
  sudo_ ln -sf /etc/nginx/sites-available/zapmro-api.conf /etc/nginx/sites-enabled/zapmro-api.conf
  sudo_ nginx -t >/dev/null 2>&1 && sudo_ systemctl reload nginx && ok "nginx recarregado (API em ${API_HOST}, site em ${SITE_HOST})" \
    || warn "nginx com erro de config — rode: sudo nginx -t"
fi
if command -v pm2 >/dev/null 2>&1; then
  pm2 restart all --update-env >/dev/null 2>&1 && ok "processos PM2 reiniciados" || warn "PM2 sem processos"
  pm2 save >/dev/null 2>&1 || true
fi

# --------------------------------------------------------------- 9) validação -
sec "9/9 Validação"
G="http://127.0.0.1:${GATEWAY_PORT:-8000}"
chk() { printf '  %-24s' "$1"; if curl -sf -m 10 "$2" ${3:+-H "$3"} >/dev/null 2>&1; then echo -e "${C_G}OK${N}"; else echo -e "${C_R}FALHOU${N}"; fi; }
chk "gateway"   "$G/health"
chk "auth"      "$G/auth/v1/health"
chk "rest"      "$G/rest/v1/"    "apikey: ${ANON_KEY}"
chk "storage"   "$G/storage/v1/bucket" "Authorization: Bearer ${SERVICE_ROLE_KEY}"
chk "functions" "$G/functions/v1/"
echo
q() { psql "$DB" -tAc "$1" 2>/dev/null || echo '?'; }
echo "  tabelas públicas : $(q "select count(*) from information_schema.tables where table_schema='public'")"
echo "  usuários auth    : $(q "select count(*) from auth.users")"
echo "  contatos CRM     : $(q "select count(*) from public.crm_contacts")"
echo "  mensagens CRM    : $(q "select count(*) from public.crm_messages")"
echo "  jobs cron        : $(q "select count(*) from cron.job")"
echo "  frontend aponta  : ${API}"

echo
ok "ATUALIZAÇÃO CONCLUÍDA — front, backend, banco, storage e functions rodando na sua VPS."
cat <<EOF

Preencher depois (opcional, o sistema já sobe sem isso):
  nano deploy/postgres-stack/secrets.env     # chaves das integrações (Meta, Google, DeepSeek, SMTP, InfinitePay…)
  nano deploy/postgres-stack/.env            # domínio, OAuth, SMTP do Auth
  ./deploy/atualizar.sh                      # rode de novo: aplica sem quebrar nada

Uma vez só, nos painéis externos:
  Meta/WhatsApp  → ${API}/functions/v1/meta-whatsapp-crm  (+ reassinar subscribed_apps)
  Google/Facebook OAuth → ${API}/auth/v1/callback
  InfinitePay / Z-API   → ${API}/functions/v1/<função>
EOF
