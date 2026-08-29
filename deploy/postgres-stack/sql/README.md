# Coloque aqui os .sql da migração

Os arquivos sao aplicados em ordem alfabetica por `./deploy/atualizar.sh` e registrados em
`public._migracoes_aplicadas` (nao reaplica se nao mudou).

Origem dos arquivos: /admincentral -> Migracao -> "Exportar dump SQL", ou `deploy/migrar-tudo.sh`.
Sugestao de nomes: `010-schema.sql`, `020-dados.sql`, `030-auth.sql`, `040-storage.sql`, `050-cron.sql`.
