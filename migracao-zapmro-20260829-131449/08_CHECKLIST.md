# Checklist — o que NÃO vem no download e você precisa refazer à mão (30–60 min)

Estes itens NÃO são exportáveis em arquivo porque vivem em plataformas de terceiros
ou são segredos criptografados. Eles só existem em memória/dashboards externos.

## 1. Secrets (valores)
- [ ] Recadastrar as ~20 chaves listadas no `07_MANIFESTO.md` no novo projeto.
      `supabase secrets set NOME="<valor>" --project-ref <NOVO_REF>`
- [ ] Os valores NÃO foram salvos em nenhum arquivo deste pacote (por segurança).

## 2. Webhooks da Meta / WhatsApp
- [ ] No Facebook App, reapontar a callback URL para o novo host das functions.
- [ ] Reassinar `subscribed_apps` de cada WABA (Graph API) — é a "reconexão".
      Os números/telefones em si VÊM no dump (tabela de números conectados);
      o que não vem é a assinatura ativa do webhook no lado da Meta.

## 3. OAuth Google e App do Facebook
- [ ] Google Cloud Console: adicionar callback `https://<NOVO_REF>.supabase.co/auth/v1/callback`.
- [ ] Facebook Developer: OAuth redirect do app para o novo callback.
      As URLs de redirect do app usam zapmro.com.br — não mudam.

## 4. Webhooks InfinitePay / Z-API
- [ ] Reapontar no dashboard de cada serviço para o novo host das functions.

## 5. Autenticação (atenção)
- [ ] `auth.users` vem no `02_auth.sql` com os HASHES de senha. Em Supabase gerenciado
      costuma restaurar; em Postgres self-hosted (GoTrue) TESTAR o login em projeto
      descartável antes — hashes de senha podem não ser compatíveis.

## 6. Cron
- [ ] Os jobs do pg_cron vêm em `04_extras.sql` (executa `SELECT cron.schedule(...)`).
      Exige `pg_cron` + `pg_net` habilitados no destino ANTES de rodar.

## 7. Validação final
- [ ] Login funciona
- [ ] Conversas/contatos aparecem no /crm
- [ ] Envio/recebimento WhatsApp
- [ ] Mídias antigas abrem (Storage restaurado)
- [ ] Webhooks de pagamento recebendo
- [ ] Cron rodando (recuperador I.A., sync Google)
