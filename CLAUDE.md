# Tesouraria ADTC Eixo do Carro

Sistema de tesouraria e secretaria da congregação **ADTC Eixo do Carro**.
Substitui a planilha `TESOURARIA - ADTCSGA EIXO DO CARRO.xlsx` (financeiro) e
`membros.xlsx` (secretaria). Idioma do produto, do código de domínio e dos
textos: **português do Brasil**.

## Estrutura do repositório

| Pasta | O que é |
|---|---|
| `appchurch/` | App Flutter (Android) usado por tesoureiro, secretaria e dirigentes |
| `apps/api/` | API NestJS (`/api/v1`) — **toda regra financeira fica aqui** |
| `apps/worker/` | Worker de notificações (vencimento de contas via FCM) |
| `supabase/migrations/` | Esquema do banco (Postgres/Supabase), RLS e cargas históricas |
| `scripts/` | Inicialização, importação da planilha e correções de dados |
| `backups/` | Backups JSON gerados antes de correções de dados (não versionar) |

## Como rodar

```powershell
# API (lê o .env da raiz)
powershell -ExecutionPolicy Bypass -File scripts/start-api.ps1

# App no celular/emulador conectado (ajuste o IP da máquina na rede)
powershell -ExecutionPolicy Bypass -File scripts/run-app.ps1 -ApiUrl http://192.168.18.238:3000

# Versão de teste/uso (APK release, instala no celular conectado por USB)
powershell -ExecutionPolicy Bypass -File scripts/build-apk.ps1
cd appchurch; flutter install --release

# Testes
cd apps/api;  npx jest --runInBand; npx tsc --noEmit -p tsconfig.json
cd appchurch; flutter analyze; flutter test
```

Depois de alterar a API: `npm run build` e **reinicie** a API — o app em uso
continua falando com o processo antigo até o reinício.

### Comandos úteis

```powershell
# Ligar a API (deixe o terminal aberto; fechar desliga a API)
cd C:\Users\emanu\Documents\tesouraria_eixodocarro
powershell -ExecutionPolicy Bypass -File scripts/start-api.ps1

# Conferir se a API está no ar (deve responder 200)
curl.exe http://localhost:3000/api/v1/health
curl.exe http://192.168.18.238:3000/api/v1/health   # pelo IP que o celular usa

# Gerar a versão nova da API e religar (após alterar o código)
cd C:\Users\emanu\Documents\tesouraria_eixodocarro\apps\api
npm run build
cd ..\..
powershell -ExecutionPolicy Bypass -File scripts/start-api.ps1

# Porta 3000 em uso (API antiga ainda ligada): encerra o processo
Get-NetTCPConnection -LocalPort 3000 -State Listen | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force }
```

## Domínio

### Fundos (origem do dinheiro)
`OFERTAS_CULTO`, `OFERTAS_ALCADAS`, `DIZIMOS` (tabelas `entry_types` e
`financial_funds`). Cada fundo tem **tipos de receita cadastrados**
(`revenue_categories`), ex.: alçadas → "Oferta alçada", "Bazar".

### Saídas
- **DESPESA**: conta paga (`payables` + `payable_payments`), com rateio entre
  fundos em `payable_funding_allocations`. Categoria em `expense_categories`.
- **REPASSE**: saída do fundo de dízimos no fechamento do ciclo
  (`accountability_closure_allocations`; pagamento em
  `accountability_closure_transfers`):
  - Dirigente = 20% do bruto de dízimos (configurável em `distribution_rules`);
  - Sede = bruto − dirigente − despesas pagas com dízimos.
  - Assim o saldo de dízimos **zera a cada ciclo**, como na planilha.
  - Se a sede ficar negativa, o fechamento é **bloqueado** até revisão.

### Ciclo de prestação de contas
- Período com início/fim definidos pelo tesoureiro (**não** é mês civil).
  Tabela: `accountability_closures`. Status `OPEN` → `CLOSED`.
- Só **um ciclo aberto** por congregação (índice único no banco).
- Ciclo aberto: valores calculados ao vivo. Saldo anterior = saldo final do
  ciclo fechado anterior **menos os repasses**.
- Fechamento (`POST /finance/closures/:id/close`): grava a foto dos saldos
  (`accountability_closure_balances`) e dos repasses e **abre o próximo ciclo**
  no dia seguinte.
- **Ciclo fechado é imutável.** Correções entram como lançamento de ajuste no
  ciclo aberto (com descrição explicando), nunca alterando o passado.
- A tabela antiga `accountability_cycles` ("Histórico importado") só existe
  porque `financial_entries.cycle_id`/`payables.cycle_id` são obrigatórios; não
  use para relatórios.

### Telas do app
- **Início (dashboard)**: título com o nome da congregação do usuário; contas
  a vencer no topo (borda animada laranja/vermelha conforme dias
  configuráveis); saldos do ciclo atual em destaque; resumo; atalho para o
  relatório.
- **Relatório do ciclo**: igual à aba `RELATORIO_MENSAL` da planilha —
  Entradas, Despesas, Saldos, Repasses; seletor de ciclo; fechar/iniciar ciclo.
- **Tesouraria = tela única de lançamentos** (`features/ledger`): extrato do
  ciclo (`GET /finance/ledger`) com contas a pagar no topo, lançamentos
  agrupados por dia, filtro Todos/Entradas/Saídas/A pagar, chips por tipo ou
  categoria, busca, detalhe (conta a pagar tem "Pagar") e botão "Lançar"
  com Oferta de culto / Oferta alçada / Dízimo / Despesa. Lançamentos
  offline aparecem como "Aguardando sincronização".
- **Lançar receita** (`features/revenues`): como as abas OFERTAS, DÍZIMOS e
  ALCADAS da planilha — data, descrição/nome, valor em PIX e em dinheiro,
  tipo cadastrado (ex.: Bazar); "Salvar e lançar outra".
- **Lançar despesa** (`features/expenses`): valor primeiro; "Paga agora" com
  data, forma (PIX/dinheiro) e rateio entre as fontes — cada fonte mostra o
  saldo disponível no ciclo e tem "Usar o que falta"; a barra mostra quanto
  falta/passou. Só salva quando a soma das fontes = valor. "Conta a pagar"
  pede vencimento (fontes escolhidas no pagamento). `POST /finance/expenses`
  revalida (`funding.ts`) e recusa data em ciclo fechado.
- **Secretaria**: membros (lista, filtro por função, cadastro com a ficha
  completa da planilha `membros.xlsx`) e aniversariantes por mês.
- **Administração**: tipos de receita e categorias de despesa (cadastro no
  banco), alertas de vencimento (dias) e campos obrigatórios dos
  formulários (`core/settings/required_fields.dart`).
- **Perfil**: usuário, congregação, perfil de acesso, sair.

### Formulários
- Campos obrigatórios têm `*` no rótulo; ao salvar com pendências, os campos
  ficam vermelhos ("Campo obrigatório.") e aparece um aviso; a partir daí o
  formulário revalida enquanto o usuário edita
  (`AutovalidateMode.onUserInteraction`).
- Quais campos são obrigatórios vem de `RequiredFieldsStore` (configurado na
  Administração). Para tornar um novo formulário configurável, declare um
  `ConfigurableForm` e use as chaves dos campos no `validator`.
- Campos de data usam `DateField` (um `FormField`, participa da validação).

## Princípios de arquitetura (boas práticas adotadas)

1. **Regra financeira só no backend.** O app exibe o que a API calcula; não
   some saldos nem calcule repasses no Flutter. Cálculos ficam em funções puras
   testáveis (`apps/api/src/finance/cycle-summary.ts`).
2. **Offline-first no app.**
   - Consultas (`ApiClient.get`) guardam a última resposta (`ApiCache`) e,
     sem conexão, usam essa cópia; a faixa "Offline" avisa o usuário.
   - Gravações (`ApiClient.send`) sem conexão vão para a fila local
     (`sync_operations`, Drift) e o `SyncService` reenvia na ordem quando a
     API volta. Todo cadastro leva **`id` gerado no app** e a API faz upsert
     por `id` → reenvio é **idempotente**.
   - Fechamento de ciclo exige conexão (é a prestação de contas oficial).
3. **Dinheiro**: `numeric(19,4)` no banco; arredonde para 2 casas só na saída
   (`round2`). Nunca compare valores monetários com `==` sem tolerância.
4. **Datas**: a API recebe/retorna `yyyy-mm-dd`; o app exibe `dd/mm/aaaa`.
5. **Segurança**:
   - `SUPABASE_SERVICE_ROLE_KEY` só no backend; o app usa apenas a chave
     pública e o token do usuário.
   - Nunca versione `.env`, `senhas.md`, chaves `*firebase-adminsdk*.json`,
     planilhas com dados pessoais ou `backups/`.
   - Dados de membros (CPF, RG, endereço) são dados pessoais (LGPD): não
     registre em log nem exponha em mensagens de erro.
6. **Mudanças em dados de produção**: script com modo prévia (sem gravar),
   backup JSON antes de aplicar e aplicação explícita (`--apply`). Exemplo:
   `scripts/fix-cycles-2026-10.py`.
7. **Migrations** são aditivas e idempotentes (`if not exists`,
   `on conflict`). Nunca edite uma migration já aplicada; crie a próxima.

## Padrão de código — Flutter (`appchurch/lib`)

Organização **por funcionalidade**, com componentes pequenos e reutilizáveis:

```
lib/
  main.dart                 # só inicialização e TesourariaApp
  core/
    api/                    # ApiClient (HTTP + cache + fila), ApiCache
    local/                  # banco local Drift (fila offline)
    sync/                   # SyncService
    settings/               # preferências do aparelho
    utils/                  # json.dart (leitura tolerante), formatters.dart
  shared/widgets/           # componentes visuais reutilizáveis
  features/<funcionalidade>/
    <nome>_page.dart        # tela (Scaffold) — orquestra, não calcula
    <nome>_service.dart     # chamadas à API da funcionalidade
    <nome>_models.dart      # modelos com fromJson tolerante
    widgets/                # componentes da funcionalidade
```

Regras:
- **Um widget por responsabilidade**; telas montam componentes
  (`SectionCard`, `ValueRow`, `DateField`, `ErrorRetry`, `EmptyMessage`,
  `PulsingBorder`...). Reaproveite antes de criar outro.
- Widgets recebem dados prontos por parâmetro; acesso à API fica nos
  `*_service.dart`. Telas recebem `ApiClient` por construtor (injeção), o que
  permite testar com `FakeApiClient`.
- JSON da API sempre via `asMap`, `asMapList`, `asDouble`, `asString`,
  `asDate` (`core/utils/json.dart`) — nunca `as Map`/`as num` direto.
- Valores: `formatMoney` / `formatDate` / `toIsoDate` (`core/utils/formatters.dart`).
- `setState` **sem** arrow que retorne `Future`:
  `setState(() { _data = future; });` (o Flutter recusa `setState(() => _data = future)`).
- Após `await`, confira `if (!mounted) return;` antes de usar `context`.
- Mensagens de erro ao usuário com `describeApiError(error)`.
- Datas de "hoje" injetáveis (`today:`) em widgets que dependem delas, para
  testes determinísticos.
- Respeitar acessibilidade: animações param com "reduzir movimento"
  (`MediaQuery.disableAnimations`).
- Nomes de classes/arquivos em inglês técnico (`MembersPage`,
  `members_service.dart`); textos e comentários de domínio em português.
- Antes de concluir: `dart format lib test`, `flutter analyze` (zero
  avisos) e `flutter test`.

### Testes Flutter
- `test/support/fake_api_client.dart`: API falsa por caminho, com modo
  `connected = false` para testar offline.
- Widget tests cobrem fluxo de tela (dashboard, relatório, membros, offline,
  aniversariantes, alertas). Animação infinita trava `pumpAndSettle`: use
  `pump(Duration)` ou dados que não disparem a animação.

## Padrão de código — API NestJS (`apps/api/src`)

- Módulo por domínio (`finance/`, `sync/`, `attachments/`); controller fino,
  regra no service, cálculo em função pura com `*.spec.ts`.
- **DTO com class-validator** para todo corpo de requisição (o
  `ValidationPipe` usa `whitelist: true`). Campos opcionais com `@IsOptional()`.
- Erros: `BadRequestException` (dado inválido/regra), `NotFoundException`,
  `UnauthorizedException`; mensagens em português, prontas para o usuário.
- Acesso ao Supabase via REST com a service role (`query`, `mutate`,
  `mutateReturning`); upsert com `on_conflict` + `resolution=merge-duplicates`
  para idempotência.
- Respostas em camelCase; colunas do banco em snake_case.
- Testes: `npx jest --runInBand`; tipagem: `npx tsc --noEmit`.

## Banco (Supabase)

- RLS habilitado em todas as tabelas; funções `is_congregation_member` e
  `has_congregation_role`.
- Perfis (`memberships.role_code`): `ADMIN`, `TREASURER`, `ASSISTANT`,
  `REVIEWER`, `SECRETARY`, `VIEWER`, `AUDITOR`.
- `congregation_id` padrão do app: `f4f1212d-b728-4a42-8fee-fec6abab33f1`.

## Estado atual (04/10/2026)

- **Versão do app:** 1.1.0 (build 2), APK release instalado no celular do
  tesoureiro (2303CRA44A, Android 15). Gerado com `scripts/build-apk.ps1`.
- **API:** roda no PC do tesoureiro (`192.168.18.238:3000`); o celular só
  sincroniza no mesmo Wi-Fi, com a API ligada (`scripts/start-api.ps1`). Fora
  desse Wi-Fi o app funciona offline e envia a fila depois.
- **Dados:** ciclo aberto 14/09/2026 a 11/10/2026; 5 ciclos fechados
  conferidos com a planilha. Correções aplicadas (bazar duplicado, oferta
  com data 2029, ciclo atual reaberto, tipos de receita, categoria GERAIS)
  com backups em `backups/`.
- **Migration 0009 aplicada (04/10/2026):** o banco recusa
  incluir/alterar/excluir receitas, pagamentos e rateios com data em ciclo
  fechado (erro `P0001`, repassado ao app pela API). Scripts de correção
  excepcional precisam de `set local app.allow_closed_cycle_edit = 'on'`
  na transação. Policy de membros usa `SECRETARY`.
- **Testes:** app 22 testes, API 18 testes — todos passando; `flutter analyze`
  sem avisos.
- **Não testado de ponta a ponta:** gravação de receita com usuário logado
  (`POST /finance/revenues` exige token real) — validar no primeiro uso.
- Repositório git local (branch `main`), **ainda sem remoto**: ao criar o
  repositório no GitHub, rode `git remote add origin <url>` e
  `git push -u origin main`.

### Como retomar
1. Ligar a API: `scripts/start-api.ps1` (confirme `GET /api/v1/health` = 200).
2. Rodar `flutter analyze`, `flutter test` e `npx jest --runInBand` para
   confirmar que nada quebrou.
3. Seguir as pendências abaixo, na ordem.

## Pendências conhecidas (próximos passos, em ordem de prioridade)

- **Mostrar lançamentos recusados na sincronização.** Hoje, se a API recusa
  uma operação da fila (ex.: data em ciclo fechado), ela vira `REJECTED` em
  `sync_operations` e some do extrato sem aviso. Exibir na faixa/extrato com
  opção de corrigir ou descartar.
- Publicar a API na nuvem com HTTPS (para sincronizar fora do Wi-Fi de casa)
  e remover os IPs locais de `network_security_config.xml`.
- Remover o código legado em memória (`FinanceService`, `/sync/push`,
  rotas antigas de `payables`/`entries`/`cycles`) — o app não usa mais.
- API em HTTPS e fora do computador local (hoje o celular precisa estar no
  mesmo Wi-Fi; `network_security_config.xml` libera HTTP só para o IP local).
- Assinar o APK com chave própria de release (hoje usa a chave de debug).
- Envio do comprovante da despesa (módulo `attachments`/Cloudinary existe na
  API, falta ligar no app).
- **Autorização na API**: validar o token e o perfil em todas as rotas (hoje só
  `/me` valida). Fechar ciclo deve exigir `ADMIN`/`TREASURER`.
- Prazos de alerta de vencimento e campos obrigatórios são salvos **por
  aparelho** (`shared_preferences`); levar para uma tabela de configuração da
  congregação, para valer para todos os usuários.
- ESLint da API está com a configuração de lint tipado quebrada
  (`parserOptions.project`).
- `scripts/import-tesouraria.py`: não importar a aba BAZAR (duplica linhas de
  ALCADAS) e preencher `revenue_category_id`.
