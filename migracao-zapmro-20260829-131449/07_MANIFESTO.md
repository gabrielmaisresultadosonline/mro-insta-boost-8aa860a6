# Manifesto ZapMRO — 20260829-131449

Origem: https://aossudsganqiapcoqthe.supabase.co  (ref aossudsganqiapcoqthe)
Domínio principal: https://zapmro.com.br

## Secrets a recriar no destino (NOMES — valores não são exportáveis por SQL)
- `BRIGHTDATA_API_TOKEN`
- `BRIGHTDATA_WEB_UNLOCKER_ZONE`
- `DEEPSEEK_API_KEY`
- `FACEBOOK_APP_ID`
- `FACEBOOK_APP_SECRET`
- `GOOGLE_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET`
- `INSTAGRAM_SESSION_ID`
- `LOVABLE_API_KEY`
- `META_CONVERSIONS_API_TOKEN`
- `RAPIDAPI_KEY`
- `SMTP_PASSWORD`
- `SUPABASE_DB_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `SUPABASE_URL`
- `WPP_BOT_TOKEN`
- `ZAPMRO_SMTP_PASSWORD`

> `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` são injetados pelo novo projeto Supabase (não recriar manualmente). `SUPABASE_DB_URL` é a string de conexão do novo banco.

## Buckets do Storage
- \`assets\` (público)
- \`crm-media\` (público)
- \`inteligencia-fotos\` (público)
- \`metodo-seguidor-backup\` (privado)
- \`metodo-seguidor-content\` (público)
- \`profile-cache\` (público)
- \`trial-screenshots\` (público)
- \`user-data\` (público)

## Webhooks externos (reapontar para o novo host das functions)
| Integração | URL atual |
|---|---|
| Meta / WhatsApp Cloud API | `https://aossudsganqiapcoqthe.supabase.co/functions/v1/meta-whatsapp-crm` |
| Meta / Instagram (MRO Direct+) | `https://aossudsganqiapcoqthe.supabase.co/functions/v1/mro-direct-webhook` |
| InfinitePay | `https://aossudsganqiapcoqthe.supabase.co/functions/v1/infinitepay-webhook` (+ webhooks específicos por produto: crm-webhook, mro-payment-webhook, zapmro-payment-webhook, corretor-webhook, ads-webhook) |
| Z-API | `https://aossudsganqiapcoqthe.supabase.co/functions/v1/zapi-webhook` |

> Se usar o proxy Cloudflare em zapmro.com.br, o host público pode ser `https://zapmro.com.br/functions/v1/...` — confira o proxy do destino.

## Auth — provedores e URLs
- Site URL: `https://zapmro.com.br`
- Redirect URLs: `https://zapmro.com.br/**`, `https://zapmro.com.br/crm`, `https://zapmro.com.br/crm/login`
- Google OAuth callback no Google Cloud: `https://<NOVO_REF>.supabase.co/auth/v1/callback`
- Facebook App OAuth redirect: apontar para o novo callback do provedor

## Variáveis de frontend (.env do build)
```
VITE_SUPABASE_URL=https://<NOVO_REF>.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=<anon do destino>
VITE_SUPABASE_PROJECT_ID=<NOVO_REF>
```
