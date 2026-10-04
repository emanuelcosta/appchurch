# Tesouraria e Secretaria

Aplicação Flutter para gestão financeira e secretaria de congregações, com backend NestJS/Express, banco Supabase, operação offline-first e integração planejada com Cloudinary e Firebase.

## Pré-requisitos

- Windows 10/11;
- Node.js 22 ou superior;
- npm;
- Flutter 3.41 ou superior;
- Dart compatível com a versão do Flutter;
- Supabase CLI, somente para aplicar migrations;
- Docker, caso seja utilizado Supabase local.

## Estrutura

```text
apps/api       Backend NestJS + Express
apps/worker    Worker para tarefas assíncronas
appchurch      Aplicativo Flutter
supabase       Migrations e seed do banco
scripts        Scripts PowerShell de automação
```

## Primeira configuração

Abra o PowerShell na raiz do projeto:

```powershell
cd C:\Users\emanu\Documents\tesouraria_eixodocarro
Copy-Item .env.example .env
```

Edite o `.env` e informe os valores do ambiente. Nunca publique esse arquivo nem coloque credenciais reais no Git.

Instale e valide tudo de uma vez:

```powershell
npm run bootstrap
```

O bootstrap instala dependências, gera os arquivos do Drift, compila e testa a API e o worker e analisa/testa o Flutter.

## Como iniciar o backend

### Modo desenvolvimento

Na raiz:

```powershell
npm install
npm run dev:api
```

Ou diretamente na pasta da API:

```powershell
cd C:\Users\emanu\Documents\tesouraria_eixodocarro\apps\api
npm install
npm run start:dev
```

Por padrão, a API inicia na porta `3000`:

```text
http://localhost:3000
```

O endpoint de saúde é:

```text
http://localhost:3000/api/v1/health
```

No PowerShell, é possível testar assim:

```powershell
Invoke-WebRequest http://localhost:3000/api/v1/health
```

### Modo produção

```powershell
cd C:\Users\emanu\Documents\tesouraria_eixodocarro\apps\api
npm install
npm run build
npm start
```

Para alterar a porta, defina `API_PORT` no `.env`, por exemplo:

```env
API_PORT=3001
```

## Worker

Em outro PowerShell, na raiz:

```powershell
npm run dev:worker
```

Ou diretamente:

```powershell
cd C:\Users\emanu\Documents\tesouraria_eixodocarro\apps\worker
npm install
npm run start:dev
```

## Banco Supabase

Configure as variáveis do Supabase no `.env`. Para aplicar as migrations, instale e autentique a Supabase CLI e execute:

```powershell
cd C:\Users\emanu\Documents\tesouraria_eixodocarro
.\scripts\migrate.ps1
```

O script interrompe a execução caso o comando `supabase` não esteja instalado.

As migrations são aplicadas nesta ordem:

1. `0001_initial_schema.sql`, tabelas e RLS habilitado;
2. `0002_rls_policies.sql`, isolamento por usuário, congregação e perfil.
3. `0003_payable_funding_source.sql`, compatibilidade e rateio das origens de contas;
4. `0004_congregation_members.sql`, cadastro de membros importados.
5. `0005_tithe_distribution.sql`, configuração opcional do percentual de dízimos;
6. `0006_monthly_closures.sql`, fundos, regras, fechamentos e repasses genéricos;
7. `0007_historical_closure.sql`, fechamento histórico conferido com a planilha.
8. `0008_retroactive_closures.sql`, demais fechamentos retroativos da planilha.

Não conecte um ambiente compartilhado ao aplicativo antes de aplicar e testar as policies RLS com usuários de congregações diferentes.

## Importar histórico da planilha

O importador financeiro está em `scripts/import-tesouraria.py`. Por segurança, a primeira execução é sempre uma prévia:

```powershell
.\scripts\import-tesouraria.ps1
```

Ele gera `import-preview.json` com receitas, despesas, categorias, membros de `membros.xlsx` e linhas ignoradas por falta de data/valor. O script não importa usuários, logins ou senhas da planilha.

A gravação exige explicitamente os IDs corretos e a chave `service_role` em variáveis de ambiente:

```powershell
$env:IMPORT_ORGANIZATION_ID = 'uuid-da-organizacao'
$env:IMPORT_CONGREGATION_ID = 'uuid-da-congregacao'
$env:IMPORT_CREATED_BY = 'uuid-do-perfil-importador'
python scripts/import-tesouraria.py `
  --members-file membros.xlsx `
  --organization-id $env:IMPORT_ORGANIZATION_ID `
  --congregation-id $env:IMPORT_CONGREGATION_ID `
  --created-by $env:IMPORT_CREATED_BY `
  --service-role-key $env:SUPABASE_SERVICE_ROLE_KEY
```

Revise o JSON antes de remover `--dry-run`. O importador usa chaves estáveis para permitir reexecução sem duplicação; contas a pagar sem vencimento permanecem identificadas na prévia para decisão administrativa.

## Aplicativo Flutter

### Comandos rápidos

Terminal 1 — iniciar a API:

```powershell
cd C:\Users\emanu\Documents\tesouraria_eixodocarro
.\scripts\start-api.ps1
```

Se o PowerShell bloquear scripts:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Deixe esse terminal aberto: fechar desliga a API. Outros comandos da API:

```powershell
# Conferir se a API está no ar (deve responder 200)
curl.exe http://localhost:3000/api/v1/health
curl.exe http://192.168.18.238:3000/api/v1/health   # pelo IP que o celular usa

# Gerar a versão nova da API e religar (após alterar o código)
cd C:\Users\emanu\Documents\tesouraria_eixodocarro\apps\api
npm run build
cd ..\..
.\scripts\start-api.ps1

# Porta 3000 em uso (API antiga ainda ligada): encerra o processo
Get-NetTCPConnection -LocalPort 3000 -State Listen | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force }
```

Terminal 2 — executar no dispositivo conectado:

```powershell
cd C:\Users\emanu\Documents\tesouraria_eixodocarro
.\scripts\run-app.ps1
```

O script carrega automaticamente as variáveis do `.env`, usa o dispositivo
Flutter conectado e aponta para `http://192.168.18.238:3000`.

Para escolher manualmente outro IP ou dispositivo:

```powershell
.\scripts\run-app.ps1 -ApiUrl http://192.168.18.238:3000 -Device <id-do-dispositivo>
```

### Preparação manual

Em outro PowerShell:

```powershell
cd C:\Users\emanu\Documents\tesouraria_eixodocarro\appchurch
flutter pub get
dart run build_runner build
flutter run
```

Para escolher um dispositivo:

```powershell
flutter devices
flutter run -d <id-do-dispositivo>
```

Em um celular físico na mesma rede Wi-Fi do computador, passe o endereço da
API por `--dart-define`. O IPv4 atual deste computador é `192.168.18.238`:

```powershell
flutter run -d <id-do-celular> `
  --dart-define=API_URL=http://192.168.18.238:3000 `
  --dart-define=SUPABASE_URL=https://seu-projeto.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=sua-chave-publica `
  --dart-define=CONGREGATION_ID=f4f1212d-b728-4a42-8fee-fec6abab33f1
```

Para carregar automaticamente a chave pública do `.env` sem copiá-la para o
terminal, use:

```powershell
.\scripts\run-app.ps1 -ApiUrl http://192.168.18.238:3000
```

Sem `-Device`, o Flutter utiliza automaticamente o dispositivo conectado
selecionado como padrão.

O celular e o computador precisam estar na mesma rede e a porta 3000 deve
estar liberada no Firewall do Windows.

O ícone e o logo do aplicativo são gerados a partir de `appchurch/assets/logo.jpg`.

## Cloudinary

O backend usará o Cloudinary para comprovantes de despesas e documentos. Preencha no `.env` somente no ambiente local/servidor:

```env
CLOUDINARY_CLOUD_NAME=
CLOUDINARY_API_KEY=
CLOUDINARY_API_SECRET=
CLOUDINARY_UPLOAD_FOLDER=tesouraria
```

`CLOUDINARY_API_SECRET` deve permanecer exclusivamente no backend. Nunca o inclua no Flutter ou em arquivos versionados.

Endpoints da integração:

```text
POST /api/v1/attachments/upload-signature
POST /api/v1/attachments/confirm
```

O primeiro recebe `entityId`, `fileName`, `mimeType` e `bytes`, retornando os parâmetros para upload assinado. O Flutter envia o arquivo diretamente ao Cloudinary e depois confirma o vínculo pelo segundo endpoint. O limite atual é 10 MB e os tipos aceitos são JPG, PNG e PDF.

> A autenticação Supabase e as policies de congregação ainda precisam ser ativadas antes de disponibilizar esses endpoints em produção.

## Firebase Cloud Messaging

O worker usa Firebase Admin SDK para enviar notificações push. Configure as variáveis somente no servidor:

```env
FIREBASE_PROJECT_ID=
FIREBASE_CLIENT_EMAIL=
FIREBASE_PRIVATE_KEY=
FIREBASE_DATABASE_URL=
```

`FIREBASE_PRIVATE_KEY` deve ficar em um secret manager ou variável protegida. Nunca coloque a chave da conta de serviço no Flutter ou em arquivos versionados.

Sem essas variáveis, o worker inicia com FCM desabilitado e informa essa condição no log. O envio em produção depende também de tokens de dispositivos ativos e policies RLS configuradas.

Para executar o ciclo de notificações, informe as congregações autorizadas no worker:

```env
NOTIFICATION_CONGREGATION_IDS=uuid-da-congregacao-1,uuid-da-congregacao-2
```

Com Supabase e FCM configurados, a cada cinco minutos o worker busca contas abertas, calcula os avisos, reserva a chave de deduplicação, envia o multicast e marca a entrega como `SENT` ou `FAILED`.

## Testes e validações

Testar somente a API:

```powershell
npm test
```

Testar API, worker e Flutter:

```powershell
npm run test:all
```

Compilar a API:

```powershell
npm --prefix apps/api run build
```

## Estado atual

A fundação executável já contém:

- API NestJS com prefixo `/api/v1`;
- endpoint de health check;
- fila offline local com Drift/SQLite;
- sincronização inicial push/pull;
- módulo financeiro inicial;
- Flutter Material 3;
- geração do ícone usando `logo.jpg`;
- configuração inicial de Cloudinary;
- planejador de notificações de contas a pagar no worker, com deduplicação;
- migrations iniciais do Supabase.

Ainda dependem da integração com ambiente real:

- autenticação Supabase;
- policies RLS completas;
- persistência definitiva de todos os fluxos;
- upload efetivo de comprovantes pelo Cloudinary;
- envio efetivo pelo Firebase Cloud Messaging e leitura de contas diretamente do Supabase;
- módulos completos de despesas, secretaria e documentos.

## Documentação

- [Plano do projeto](./PLANO_PROJETO_TESOURARIA.md)
- [Especificação técnica](./SDD_PROJETO_TESOURARIA_SECRETARIA.md)
- [Manual de uso](./MANUAL_USO_APP.md)
## Fechamento mensal

O fechamento mensal deve ser feito por período fechado, sem apagar ou alterar os
lançamentos originais:

1. definir o primeiro e o último dia do mês;
2. confirmar todas as receitas do período;
3. conferir pagamentos realizados, inclusive pagamentos parciais;
4. revisar o rateio de cada pagamento entre dízimos, ofertas de culto e ofertas alçadas;
5. conferir o saldo anterior, as entradas, as saídas pagas e o saldo final por origem;
6. conferir o repasse do dirigente e o valor destinado à sede;
7. somente então fechar o ciclo de prestação de contas.

O relatório está disponível em:

```text
GET /api/v1/finance/monthly-report?congregationId=<id>&startDate=2026-04-01&endDate=2026-04-30
```

Ele calcula `openingByType`, entradas (`byType`), despesas efetivamente pagas
(`expensesByType`) e `closingByType`. O repasse de dízimos segue:

```text
repasse do dirigente = dízimos brutos × percentual configurado
repasse da sede = dízimos brutos − repasse do dirigente − despesas pagas com dízimos
```

Contas abertas ou apenas previstas não reduzem o repasse. Em pagamentos parciais,
o rateio da conta é aplicado proporcionalmente ao valor efetivamente pago.

## Fechamento por período e repasses

O fechamento não fica preso ao mês do calendário. Cada congregação pode usar
períodos mensais, quinzenais ou datas personalizadas. O sistema grava um
`accountability_closures` com os saldos de abertura, entradas, despesas pagas,
saldos finais, regras aplicadas e repasses. O saldo final de um fechamento
torna-se o saldo de abertura do próximo período.

Os fundos são configurados em `financial_funds`. As regras de distribuição ficam
em `distribution_rules` e aceitam percentual ou valor fixo, ordem de aplicação,
origem e destino. Os repasses planejados e efetivados ficam em
`accountability_closure_transfers`. Portanto, “dirigente” e “sede” são apenas
destinos iniciais, não conceitos obrigatórios do sistema.

Para o período de 14/09/2026 a 11/10/2026, conforme a planilha, a conferência
esperada é:

```text
Ofertas de culto: 35,27 + 19,10 - 16,00 = 38,37
Ofertas alçadas: 561,34 + 430,74 - 972,69 = 19,39
Dízimos: 0,00 + 363,00 - 0,00 = 363,00
Repasse do dirigente: 363,00 × 20% = 72,60
Repasse da sede: 363,00 - 72,60 - 0,00 = 290,40
```

Os repasses devem ser registrados no fechamento como transferências próprias.
Eles não devem ser lançados como despesas comuns da congregação, pois possuem
destinatário e finalidade de prestação de contas. A migration
`0006_monthly_closures.sql` cria os fundos iniciais e as regras equivalentes à
planilha: 20% dos dízimos para o dirigente e 80% do saldo após despesas para a
sede.

A migration `0007_historical_closure.sql` importa o fechamento histórico da
planilha de 14/09/2026 a 11/10/2026. Ela não duplica receitas nem despesas:
apenas grava o saldo de abertura, os totais conferidos, o saldo final e as
distribuições calculadas para auditoria.

## Ciclo aberto de prestação de contas

Uma prestação pode ser criada somente com a data inicial:

```text
POST /api/v1/finance/closures
{
  "congregationId": "<id>",
  "periodStart": "2026-10-12",
  "notes": "Prestação de contas em aberto"
}
```

Enquanto estiver aberta, consulte a prévia:

```text
GET /api/v1/finance/closures/<closureId>/preview?endDate=2026-10-20
```

Ao concluir a conferência, informe a data final. O período é inclusivo:

```text
POST /api/v1/finance/closures/<closureId>/close
{
  "periodEnd": "2026-11-11",
  "notes": "Conferido pelo tesoureiro"
}
```

O fechamento grava o retrato dos saldos por fundo e as distribuições calculadas.
Depois de fechado, o saldo final deve ser usado como abertura do próximo ciclo.
