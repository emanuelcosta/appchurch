# SDD — Especificação de Design do Sistema

**Status:** proposta para aprovação  
**Versão:** 0.1  
**Data:** 2026-10-03  
**Documento relacionado:** [PLANO_PROJETO_TESOURARIA.md](./PLANO_PROJETO_TESOURARIA.md)

## 1. Finalidade e escopo

Este documento transforma o plano funcional em regras técnicas verificáveis para os módulos de Tesouraria e Secretaria. Ele define responsabilidades, segurança, invariantes financeiras, estados, contratos operacionais, tratamento de falhas e critérios mínimos de aceite.

Inclui:

- multi-organização e multi-congregação;
- autenticação e autorização;
- módulos e tipos configuráveis;
- ciclos de prestação de contas;
- receitas, despesas e pagamentos parciais;
- saldo derivado de movimentos;
- auditoria;
- relatórios;
- notificações push;
- membros, famílias e aniversários;
- fichas, certificados e documentos versionados;
- migração da planilha.

Ficam fora do MVP: integração bancária, conciliação automática, estoque detalhado do bazar, assinatura digital qualificada, contabilidade completa por partidas dobradas e envio por WhatsApp. A operação offline-first faz parte do MVP.

## 2. Arquitetura e responsabilidades

```text
Flutter (Android/Web)
        |
        | HTTPS + WebSocket
        v
API e workers próprios (NestJS/TypeScript + Express adapter)
        |
        +--> Supabase PostgreSQL/Auth/Storage/Realtime
        |
        +--> Firebase Admin SDK --> FCM
```

| Componente | Responsabilidade |
|---|---|
| Flutter | apresentação, formulários, cache, navegação e UX |
| API | autenticação, autorização, regras, transações e contratos |
| Worker | notificações, PDFs e tarefas assíncronas |
| PostgreSQL | persistência, constraints, transações e consultas |
| Supabase Auth | identidade e tokens |
| Supabase Storage | arquivos privados |
| Supabase Realtime | eventos; não é fonte única da verdade |
| Firebase FCM | transporte de push |

O Flutter não acessará tabelas financeiras diretamente. O backend será o ponto de entrada oficial, mesmo com RLS habilitado.

### Decisão de backend HTTP

O backend será implementado em **NestJS com o adaptador Express**.

Essa escolha é preferível a uma aplicação Express sem estrutura porque o projeto possui:

- múltiplos domínios;
- regras financeiras sensíveis;
- autorização por organização e congregação;
- auditoria;
- workers e tarefas assíncronas;
- geração de documentos;
- notificações;
- contratos OpenAPI;
- necessidade de testes e manutenção por vários módulos.

O Express continuará sendo o servidor HTTP subjacente, mas a aplicação utilizará os recursos arquiteturais do NestJS:

- módulos;
- controllers;
- services/use cases;
- dependency injection;
- guards;
- pipes de validação;
- interceptors;
- filtros globais de exceção;
- documentação OpenAPI;
- integração com filas e workers;
- testes unitários e de integração.

Não utilizar `app.post(...)` e regras de negócio diretamente em arquivos de rota. Rotas devem chamar casos de uso e respeitar os limites dos módulos.

#### Quando considerar Fastify

O NestJS permite trocar o adaptador para Fastify posteriormente. Essa mudança só deve ocorrer após medição real de desempenho ou necessidade operacional. O MVP começará com Express para reduzir complexidade e aproveitar a maturidade do ecossistema, middleware e ferramentas de diagnóstico.

#### Stack de backend definida

```text
NestJS
TypeScript
Express adapter
PostgreSQL/Supabase
Prisma ou Drizzle, após decisão de persistência
Zod ou class-validator
OpenAPI/Swagger
BullMQ + Redis para jobs
Firebase Admin SDK
Pino para logs estruturados
```

## 3. Requisitos não funcionais

### Segurança

- TLS em todas as comunicações;
- segredos em secret manager ou variáveis protegidas;
- nenhuma chave privada Firebase no aplicativo;
- autorização por organização e congregação em todas as consultas;
- logs sem CPF, dados de dizimistas, tokens ou conteúdo de documentos;
- rate limiting em autenticação, emissão e upload;
- validação de entrada no backend;
- rotação de sessões e segredos;
- análise de vulnerabilidades das dependências.

### Consistência e desempenho

- valores monetários exatos;
- transação atômica para comando e movimentos;
- idempotência em comandos;
- reconciliação periódica entre receitas, saídas e movimentos;
- nenhum saldo editável pelo cliente;
- relatórios extensos processados como job assíncrono;
- notificações processadas em janela de até 10 minutos do horário previsto, meta a confirmar.

## 4. Tenancy e identidade

Entidades:

- `organizations`;
- `congregations`;
- `congregation_accounts`;
- `profiles`;
- `memberships`;
- `roles`;
- `permissions`;
- `role_permissions`.

`profiles.id` corresponde ao usuário do Supabase Auth. `memberships` define o acesso à organização e à congregação.

### Conta inicial da congregação e provisionamento

Cada congregação possui uma conta administrativa inicial (`congregation_accounts`) para ativação do ambiente. Essa conta não substitui usuários pessoais.

Campos sugeridos:

- `id`;
- `congregation_id`;
- `auth_user_id`;
- `account_type`;
- `status`;
- `first_access_at`;
- `last_access_at`;
- `created_at`;
- `disabled_at`.

Fluxo obrigatório:

1. Provisionar a conta inicial com convite ou credencial temporária.
2. Exigir troca da senha no primeiro acesso.
3. Exigir aceite dos termos internos e, quando habilitado, MFA.
4. Permitir confirmar dados e configurações básicas da congregação.
5. Permitir criar o primeiro perfil pessoal com papel `TESOUREIRO`.
6. Associar o tesoureiro à congregação através de `memberships`.
7. Registrar o provisionamento e o usuário criador em auditoria.
8. Recomendar desativar ou restringir a conta inicial após a criação do tesoureiro.

O login da congregação não deve ser compartilhado para registrar operações. Lançamentos, aprovações e emissão de documentos devem usar usuários pessoais. Isso garante autoria, auditoria e revogação individual.

Se a organização decidir manter a conta inicial ativa, ela deve possuir permissões mínimas e não pode aprovar a própria operação quando houver regra de dupla conferência.

Regras:

1. O backend valida JWT, emissor, audiência, expiração e usuário ativo.
2. O usuário é obtido do token, nunca do corpo da requisição.
3. O escopo é derivado da associação autenticada.
4. Toda entidade de negócio possui `organization_id`; entidades da congregação possuem também `congregation_id`.
5. IDs fora do escopo não podem ser enumerados.
6. Transferências entre congregações exigem comando autorizado e auditoria.
7. RLS é defesa adicional e deve ter testes de isolamento.
8. Uma conta inicial só administra a própria congregação e não pode criar usuários em outra congregação.
9. O primeiro tesoureiro só pode ser criado pela conta inicial ou por um administrador superior autorizado.
10. Não é permitido remover o último administrador funcional sem criar outro previamente.
11. Desativar a conta inicial não desativa automaticamente usuários pessoais já criados.

## 5. Convenções de dados

### Identidade e auditoria

- UUID v4 ou v7;
- `created_at` e `updated_at` em UTC;
- `created_by` e `updated_by`;
- soft delete somente para cadastros;
- registros financeiros nunca são apagados fisicamente.

### Dinheiro

Usar `numeric(19,4)` no PostgreSQL e `Decimal` no backend. A moeda inicial é BRL.

- valores de entrada maiores que zero, salvo ajustes explícitos;
- soma das linhas exatamente igual ao total;
- arredondamento definido no domínio, nunca por `float`;
- limites máximos validados no servidor;
- valores negativos somente em movimentos de estorno autorizados.

### Datas

- datas de negócio: `date`;
- horários: `time`;
- instantes: `timestamptz`;
- timezone por organização, inicialmente pendente de confirmação;
- relatórios usam intervalo inclusivo de datas locais;
- scheduler converte horário local para UTC.

## 6. Configuração por congregação

Tabelas:

- `modules`;
- `organization_modules`;
- `congregation_modules`;
- `entry_types`;
- `revenue_categories`;
- `entry_type_fields`;
- `expense_categories`;
- `payment_methods`.

Desativar módulo não apaga histórico. `entry_types` representam o tipo de receita e possuem código estável, nome editável, escopo, status, obrigatoriedade de contribuinte, anonimato permitido, aprovação e ordem.

`revenue_categories` são subcategorias configuráveis por congregação e vinculadas a um tipo de receita. Isso permite, por exemplo:

```text
Tipo: Oferta de culto
  - culto regular
  - culto evangelístico

Tipo: Oferta alçada
  - construção/manutenção
  - ação social
  - missão
  - propósito especial
```

O nome e o propósito da categoria podem ser ajustados pela administração, sem alterar lançamentos antigos. Para `Oferta alçada`, a categoria de finalidade deve ser obrigatória, salvo uma exceção administrativa auditada.

Campos dinâmicos declaram chave, tipo, obrigatoriedade, limite, opções e máscara. JSONB não substitui validação de esquema no backend.

## 7. Máquinas de estado

### Ciclo

```text
RASCUNHO -> ABERTO -> EM_CONFERENCIA
EM_CONFERENCIA -> ABERTO
EM_CONFERENCIA -> AGUARDANDO_APROVACAO
AGUARDANDO_APROVACAO -> FECHADO
AGUARDANDO_APROVACAO -> EM_CONFERENCIA
FECHADO -> REABERTO -> EM_CONFERENCIA
RASCUNHO -> CANCELADO
ABERTO -> CANCELADO
```

Toda transição exige permissão, motivo quando aplicável e auditoria. `FECHADO` recusa edição financeira comum.

### Receita

```text
RASCUNHO -> CONFIRMADA -> CANCELADA
CONFIRMADA -> ESTORNADA
```

Somente `CONFIRMADA` participa do saldo.

### Despesa

```text
RASCUNHO -> ABERTA -> PARCIALMENTE_PAGA -> PAGA
ABERTA -> CANCELADA
PARCIALMENTE_PAGA -> ESTORNADA
PAGA -> ESTORNADA
```

O status é derivado dos pagamentos confirmados e não é livremente editável.

Toda despesa deve possuir uma `expense_category_id` ativa da própria congregação. A categoria é obrigatória, não pode ser informada como texto livre no lançamento e deve permanecer no histórico mesmo que seja desativada posteriormente.

Uma despesa pode ser marcada como **conta a pagar**, contendo:

- `due_date`, obrigatório para contas a pagar;
- `scheduled_amount`;
- `payment_status` (`ABERTA`, `PARCIALMENTE_PAGA`, `PAGA`, `VENCIDA`);
- `notification_days_before`, herdado da configuração da congregação no momento da criação;
- `last_notification_at` e chave de deduplicação do aviso.

O usuário pode substituir a antecedência apenas se possuir permissão administrativa. A configuração padrão fica em `notification_preferences` por congregação e deve aceitar zero ou mais dias antes do vencimento, além de horário, aviso no dia e repetição após atraso.

O fechamento de uma conta ocorre pelo registro de pagamentos em `payable_payments`. O sistema permite pagamento parcial, atualiza para `PARTIALLY_PAID` e calcula o restante. Cada pagamento possui um rateio de origens em `payable_funding_allocations`; a soma do rateio deve ser igual ao valor pago. Quando a soma dos pagamentos confirmados atingir o valor da conta, atualiza automaticamente para `PAID`, interrompe os alertas e reduz cada saldo conforme seu rateio. Não é permitido pagar acima do valor devido sem ajuste autorizado.

### Documento

```text
RASCUNHO -> EM_REVISAO -> APROVADO -> PUBLICADO -> ARQUIVADO
```

Versão publicada é imutável; alterações criam nova versão.

## 8. Invariantes financeiras

1. Receita confirmada possui ao menos uma linha.
2. Linhas pertencem ao mesmo escopo da receita.
3. Soma das linhas é igual ao total.
4. Cada receita informa `CASH`, `PIX` ou os dois, com valores positivos.
5. Pagamento pertence à mesma despesa e ao mesmo escopo.
6. Pagamentos não excedem o devido, salvo ajuste autorizado.
7. Despesa paga possui pagamento confirmado.
8. Cancelamento e estorno produzem movimentos inversos.
9. Cada operação confirmada produz movimentos uma única vez.
10. O cliente não informa saldo final.
11. Repetição com a mesma chave de idempotência não cria movimento novo.
12. Ciclo fechado ou cancelado recusa novos movimentos.
13. Uma entrada pertence a um único ciclo.
14. Não há sobreposição de ciclos ativos, salvo decisão explícita.
15. Movimento financeiro é imutável.
15. Despesa exige categoria ativa pertencente à mesma congregação.
16. Conta a pagar exige data de vencimento posterior ou igual à data do lançamento.
17. Pagamento não pode exceder o saldo da conta a pagar sem ajuste autorizado.
18. Conta paga não gera novas notificações de vencimento.
19. Toda receita pertence a um `entry_type_id` e seu saldo pode ser consultado separadamente.
20. Uma receita de `Oferta alçada` deve possuir categoria de finalidade ativa da mesma congregação.

Saldo:

```text
saldo = saldo_inicial + entradas_confirmadas - saídas_confirmadas
```

Despesa prevista sem pagamento reduz pendências e compromissos, mas não reduz saldo realizado.

No MVP financeiro existem exatamente três saldos de origem independentes:

- `DIZIMOS`;
- `OFERTAS_CULTO`;
- `OFERTAS_ALCADAS`.

Esses tipos são receitas distintas. Outras receitas poderão ser habilitadas pela administração, mas não devem ser somadas a esses saldos sem configuração explícita.

Ao lançar uma despesa ou conta a pagar, o usuário deve informar `fundingSources`, um mapa com uma ou mais origens e seus valores. A soma deve ser igual ao valor da conta, usando somente `DIZIMOS`, `OFERTAS_CULTO` e `OFERTAS_ALCADAS`. O pagamento confirmado reduz cada saldo conforme o rateio; uma despesa prevista não reduz saldo realizado.

Além do saldo consolidado, o sistema deve apresentar:

```text
saldo_por_tipo_de_receita =
  soma das receitas confirmadas agrupadas por entry_type_id

saldo_por_categoria_de_receita =
  soma das receitas confirmadas agrupadas por revenue_category_id
```

```text
saldo_disponivel_por_tipo =
  receitas_confirmadas_do_tipo - pagamentos_confirmados_com_aquela_origem
```

Endpoints de consulta:

- `GET /api/v1/finance/cycles/:cycleId/balance/by-revenue-type`;
- `GET /api/v1/finance/cycles/:cycleId/balance/by-revenue-category`.

Uma oferta alçada não deve ser misturada automaticamente ao saldo de oferta de culto ou dízimos. O relatório pode exibir o consolidado geral, mas deve manter os três saldos e as finalidades de ofertas alçadas separados. Uma despesa pode usar várias origens, desde que o rateio seja explícito e validado.

## 9. Ciclos

Política recomendada para o MVP:

- um ciclo `ABERTO` por congregação;
- ciclos sem sobreposição;
- `start_date <= end_date`;
- despesa pertence ao ciclo escolhido;
- pagamento pertence ao ciclo da despesa;
- despesa possui categoria ativa da congregação;
- conta a pagar possui vencimento e configuração de antecedência;
- retroativo em ciclo fechado exige ajuste;
- novo ciclo herda saldo aprovado anterior;
- primeiro ciclo exige saldo inicial informado e aprovado.

Essas regras devem ser confirmadas antes da produção. Reabrir ciclo exige recálculo e nova aprovação dos ciclos afetados.

## 10. Movimentos, concorrência e outbox

`financial_movements` contém escopo, ciclo, direção, valor, origem, data, idempotency key, status, usuário e timestamps. Índices únicos impedem duplicação da mesma origem confirmada.

Todo comando mutável aceita `Idempotency-Key`, obrigatória para confirmar receita, registrar pagamento, estornar, fechar/aprovar/reabrir ciclo e emitir documento. Reutilizar a chave com payload diferente retorna conflito.

Fechamento, aprovação e pagamentos usam transação com lock (`FOR UPDATE`) ou controle otimista por `version`.

Na mesma transação da alteração de domínio, gravar `outbox_events` com tipo, agregado, payload mínimo, tentativas e disponibilidade. Workers processam eventos; falha assíncrona não desfaz a operação financeira.

## 11. API

A API usa `/api/v1`, OpenAPI e códigos de erro estáveis.

```json
{
  "code": "CYCLE_CLOSED",
  "message": "O ciclo está fechado para novos lançamentos.",
  "details": {},
  "request_id": "uuid"
}
```

Códigos mínimos: `UNAUTHENTICATED`, `FORBIDDEN`, `NOT_FOUND`, `VALIDATION_ERROR`, `CONFLICT`, `IDEMPOTENCY_CONFLICT`, `CYCLE_CLOSED`, `INVALID_STATE`, `DUPLICATE_RECORD`, `RATE_LIMITED` e `INTERNAL_ERROR`.

Endpoints mínimos:

- `GET /api/v1/me`;
- `GET /api/v1/congregations`;
- `GET/POST /api/v1/cycles`;
- `POST /api/v1/entries`;
- `POST /api/v1/entries/:id/confirm`;
- `POST /api/v1/expenses`;
- `POST /api/v1/expenses/:id/payments`;
- `POST /api/v1/cycles/:id/submit`;
- `POST /api/v1/cycles/:id/approve`;
- `POST /api/v1/cycles/:id/reopen`;
- `GET /api/v1/reports`;
- `POST /api/v1/devices`;
- `GET/PUT /api/v1/notification-preferences`;
- `GET/POST /api/v1/finance/expense-categories`;
- `POST /api/v1/finance/expenses`;
- `POST /api/v1/finance/payables`;
- `POST /api/v1/finance/payables/:id/payments`;
- `GET/POST /api/v1/people`;
- `POST /api/v1/documents/issue`.

O cliente decide comportamento pelo `code`, nunca por interpretação do texto.

## 12. Realtime e Flutter

1. Flutter envia comando à API.
2. API confirma transação.
3. API publica evento.
4. Flutter recebe invalidação.
5. Flutter refaz consulta autorizada.

Realtime não confirma gravação. Em desconexão, o app consulta novamente. Estado local diferencia confirmado, rascunho, pendente e erro.

## 12.1 Design system e atualização manual

### Design system

O Flutter utilizará Material 3 como design system oficial. A interface deve ser minimalista, consistente e orientada às tarefas mais frequentes.

Diretrizes:

- O padrão será um modo operacional simples, adequado a usuários leigos e sem exigir conhecimento contábil, técnico ou de banco de dados.
- Usar linguagem cotidiana e orientada à ação: “Registrar entrada”, “Pagar conta”, “Fechar prestação de contas” e “Emitir ficha”.
- Aplicar divulgação progressiva: campos e filtros avançados ficam ocultos até serem solicitados ou autorizados.
- Separar navegação operacional da área de gestão. Configurações, permissões, tipos, templates e regras avançadas ficam em “Administração”.
- Utilizar assistentes passo a passo para tarefas complexas, com resumo antes da confirmação.
- Manter contexto visível: congregação, ciclo, período, status e usuário atual.
- Cada tela deve possuir estados de carregamento, vazio, sucesso, erro e sem permissão com orientação objetiva.
- Erros devem explicar o que aconteceu e como resolver, sem expor detalhes técnicos.
- Ações destrutivas ou sensíveis exigem confirmação, motivo e permissão.
- usar `ThemeData` centralizado e `ColorScheme` por organização ou aplicação;
- definir tipografia, espaçamentos, raios, elevação e estados em tokens compartilhados;
- utilizar componentes Material nativos antes de criar componentes próprios;
- manter navegação adaptativa: `NavigationBar` no mobile e `NavigationRail` ou navegação lateral no web/desktop;
- utilizar `Card`, `ListTile`, `DataTable`, `Form`, `Dialog`, `SnackBar` e `Banner` com propósito claro;
- destacar no dashboard somente saldo, pendências, ações rápidas e alertas;
- garantir responsividade, contraste, foco por teclado, semântica e áreas de toque adequadas;
- evitar excesso de cores, gráficos, sombras, modais e informações simultâneas.

### Puxar para atualizar

Telas com conteúdo rolável devem usar `RefreshIndicator` ou equivalente Material:

1. o usuário puxa a tela para baixo;
2. o Flutter solicita os dados atuais à API;
3. o indicador permanece visível durante a operação;
4. os dados só são substituídos após resposta válida;
5. em erro, os dados anteriores permanecem e a interface exibe mensagem clara;
6. em sucesso, a última atualização é registrada opcionalmente.

O gesto é complementar ao Realtime e não substitui a atualização automática. Em web/desktop, onde o gesto pode não existir, deve haver botão ou ação de atualizar equivalente. A atualização deve ser cancelável quando a tela for descartada e não pode criar comandos financeiros ou duplicar requisições.

### Modos de uso e permissões

O aplicativo deve ter dois níveis de experiência:

#### Modo operacional

Voltado para tesoureiros, auxiliares e secretários:

- dashboard resumido;
- ações rápidas;
- formulários curtos;
- poucos campos obrigatórios;
- filtros básicos;
- confirmação clara;
- ajuda contextual;
- nenhuma configuração estrutural.

#### Modo de gestão

Voltado para administradores, responsáveis e usuários autorizados:

- módulos por congregação;
- tipos de entrada;
- campos dinâmicos;
- permissões;
- ciclos e regras;
- notificações;
- categorias;
- templates e documentos;
- relatórios avançados;
- auditoria.

O modo não deve ser apenas uma preferência visual: as opções de gestão devem ser protegidas por autorização no backend. Um usuário avançado pode acessar configurações administrativas, mas um usuário leigo não deve receber menus, campos ou decisões que não precisa executar.

O usuário poderá acessar “Mais opções” ou “Filtros avançados” quando sua permissão permitir. O aplicativo deve lembrar preferências de visualização sem alterar regras de negócio ou permissões.

## 13. Offline-first e sincronização

O aplicativo deve continuar utilizável sem internet. Os dados autorizados são mantidos em banco local SQLite usando Drift; quando a conexão retornar, as operações pendentes são sincronizadas com a API.

### 13.1 Componentes locais

- banco local SQLite usando Drift;
- repositórios locais para leitura imediata;
- `sync_queue` para comandos pendentes;
- `sync_cursors` para paginação incremental;
- `connectivity_plus` para detectar mudanças de rede;
- idempotency key gerada antes de cada comando;
- estado visual `Sincronizado`, `Pendente`, `Sincronizando` ou `Conflito`.

Dados financeiros sensíveis devem ser criptografados em repouso quando suportado pela plataforma. O cache deve respeitar a congregação ativa e ser removido no logout ou na troca de escopo.

### 13.2 Fluxo de uma operação offline

1. O usuário preenche o formulário.
2. O aplicativo valida regras locais básicas.
3. Grava o comando e os dados locais em uma transação.
4. Gera uma idempotency key estável.
5. Atualiza a tela imediatamente como `Pendente`.
6. Quando houver internet, envia a fila na ordem de dependência.
7. A API valida novamente autorização e regras financeiras.
8. Em sucesso, marca o item como `Sincronizado`.
9. Em conflito, preserva os dados locais e mostra uma ação orientada.
10. Em erro temporário, aplica retentativa com backoff.

### 13.3 O que pode ser feito offline

- consultar dados sincronizados;
- preparar e confirmar localmente lançamentos permitidos;
- registrar receitas;
- registrar despesas;
- registrar pagamentos;
- cadastrar pessoas e rascunhos de documentos;
- consultar ciclos e relatórios já sincronizados.

Emissão oficial de PDF, aprovação final, fechamento de ciclo, publicação de template e ações administrativas sensíveis devem aguardar sincronização com o servidor, salvo regra específica aprovada.

### 13.4 API de sincronização

Endpoints mínimos:

- `POST /api/v1/sync/push`;
- `GET /api/v1/sync/pull?cursor=...`;
- `POST /api/v1/sync/resolve-conflict`.

O `push` aceita lote limitado de comandos idempotentes e retorna o resultado individual de cada item. O `pull` retorna alterações autorizadas desde o cursor. O cursor só é avançado após persistência local confirmada.

### 13.5 Dependências e conflitos

Cada operação possui:

- `operation_id`;
- `idempotency_key`;
- `entity_type`;
- `entity_id`;
- `operation_type`;
- `payload`;
- `depends_on`;
- `base_version`;
- `status`;
- `attempt_count`;
- `last_error`.

Pagamentos dependem da despesa local; estornos dependem do lançamento original. O servidor usa `base_version` para detectar alteração concorrente. Nunca sobrescrever silenciosamente dados modificados por outro usuário.

Conflitos financeiros não são resolvidos automaticamente por “última gravação”. O aplicativo deve exibir o conflito e exigir revisão autorizada, estorno ou novo lançamento.

### 13.6 Limites de segurança

- confirmar a congregação e o usuário antes de sincronizar;
- rejeitar payload fora do escopo;
- limitar tamanho de fila e anexos;
- não armazenar tokens ou segredos no banco local;
- não considerar operação sincronizada apenas porque foi salva no dispositivo;
- mostrar claramente o saldo local possivelmente desatualizado;
- registrar falhas para suporte e auditoria.

## 14. Arquivos

O Cloudinary será usado para os arquivos de mídia, com pastas privadas por organização/congregação:

- `financial-proofs`;
- `member-documents`;
- `generated-documents`.

O backend deve gerar assinaturas de upload do Cloudinary somente após autenticar o usuário e validar a congregação. A fundação já expõe os endpoints de assinatura e confirmação, mas eles permanecem bloqueados para produção até a autenticação Supabase e as policies de congregação estarem ativas. O aplicativo recebe apenas `cloud_name`, `api_key`, `timestamp`, `public_id`, `resource_type` e `signature`; `CLOUDINARY_API_SECRET` permanece exclusivamente no backend/secret manager.

Uploads têm limite de tamanho, MIME permitido, nome gerado pelo servidor, vínculo de escopo, verificação e URL assinada de leitura com curta duração. O backend persiste `public_id`, `resource_type`, `format`, `bytes`, `sha256`, entidade vinculada e status do anexo. A exclusão é feita pelo backend usando a API do Cloudinary, nunca diretamente pelo cliente.

Para comprovantes de despesas, o fluxo é:

1. criar a despesa localmente e registrar o arquivo na fila offline;
2. ao recuperar conexão, solicitar uma assinatura ao backend;
3. enviar o arquivo diretamente ao Cloudinary;
4. confirmar no backend o upload e vincular o `public_id` à despesa;
5. marcar a operação financeira e o anexo como sincronizados.

Falhas no upload não duplicam a despesa: a operação permanece pendente e pode ser repetida com a mesma chave de idempotência.

## 15. Notificações

O horário é salvo no timezone local e convertido para UTC. O worker busca uma janela tolerante, não igualdade exata de timestamp.

Índice de deduplicação:

Para contas a pagar, o worker calcula a janela usando a data civil da congregação:

```text
data_aviso = data_vencimento - notification_days_before
```

O planejador já implementa três tipos de evento:

- `BEFORE_DUE`, quando chega a data configurada de antecedência;
- `DUE_TODAY`, quando a conta vence no dia e a preferência está ativa;
- `OVERDUE`, quando a conta está vencida e a repetição foi habilitada.

Contas `PAID` ou `CANCELLED` são ignoradas. A chave determinística combina congregação, conta, tipo e data do evento:

```text
congregation_id:payable_id:event_type:event_date
```

Essa chave deve ser persistida em uma tabela de histórico/outbox antes do envio FCM, garantindo que novas execuções do worker não dupliquem notificações. O envio real ao Firebase e a leitura dos payables no Supabase dependem da configuração de credenciais e da implementação dos repositórios de produção.

O schema prevê:

- `device_push_tokens`, com token por usuário/dispositivo, plataforma, atividade e último uso;
- `notification_deliveries`, com chave única de deduplicação, destinatário, payload, tentativas, status e erro.

O worker já possui um `FcmSender` baseado no Firebase Admin SDK. Ele recusa o envio quando as credenciais não estão configuradas, envia mensagens multicast para tokens ativos e retorna contadores de sucesso/falha. A implementação de produção deve reservar a chave em `notification_deliveries` antes do envio, marcar `SENT` somente após o retorno do FCM e desativar tokens inválidos.

O `NotificationRunner` executa essa sequência a cada cinco minutos para as congregações informadas em `NOTIFICATION_CONGREGATION_IDS`. Ele não trata ausência de configuração como sucesso: registra que a execução foi ignorada. Falhas na consulta, reserva ou envio são lançadas e registradas pelo processo do worker. A desativação automática de tokens retornados como inválidos pelo FCM deve ser adicionada ao adaptador de produção.

## 15.1 Policies RLS e isolamento

A migration `0002_rls_policies.sql` cria as funções `is_congregation_member` e `has_congregation_role`, executadas com `security definer` e `search_path` fixo. As policies usam o usuário autenticado (`auth.uid()`) para limitar leitura e escrita à congregação da associação ativa.

Regras principais:

- usuários só consultam dados da própria congregação;
- administração de usuários, categorias, tipos e preferências exige `ADMIN`;
- tesouraria exige `ADMIN`, `TREASURER` ou `ASSISTANT`;
- tokens push só podem ser registrados pelo próprio usuário;
- entregas de notificação ficam visíveis ao destinatário ou administrador;
- movimentos e auditoria não podem ser alterados pelo cliente;
- o worker usa `service_role` somente no servidor, nunca no Flutter.

Antes de produção, aplicar as migrations em banco de homologação e executar testes com usuários de congregações diferentes. A ordem é `0001_initial_schema.sql` e depois `0002_rls_policies.sql`; não liberar o aplicativo conectado ao Supabase antes dessa validação.

```text
escopo + destinatário + assunto + tipo de notificação + data local programada
```

Regras:

- retry exponencial para falha temporária;
- máximo de tentativas;
- dead letter para falha permanente;
- desativação de token inválido;
- pagamento confirmado cancela alertas futuros;
- usuário pode ter vários dispositivos;
- token pode mudar e deve atualizar `last_seen_at`.

O FCM Web precisa ser configurado separadamente se o painel web receber push.

## 16. Secretaria e documentos

### Pessoas

CPF não é obrigatório, especialmente para crianças. Homônimos geram alerta; não há exclusão automática. Mesclagem exige permissão e preserva histórico.

### Aniversários

Usar data local, deduplicação diária e preferências de divulgação. O ano de nascimento é omitido por padrão. Somente membros elegíveis e destinatários autorizados recebem alertas.

### Templates

O modelo oficial usa blocos controlados e tags whitelist, por exemplo:

```text
{{pessoa.nome_completo}}
{{pessoa.data_nascimento}}
{{membro.data_batismo}}
{{congregacao.nome}}
{{documento.numero}}
{{documento.data_emissao}}
```

Não permitir JavaScript, SQL, iframes, URLs externas livres ou expressões arbitrárias. Tag obrigatória ausente bloqueia emissão; tag opcional segue regra definida no catálogo.

Cada documento emitido registra pessoa, escopo, tipo, versão do template, emissor, número, data, hash do PDF, status e arquivo privado. Reemissão cria outro documento.

## 17. Auditoria e LGPD

`audit_events` registra escopo, usuário, ação, entidade, entidade ID, antes/depois permitido, motivo, request ID e timestamp. Não registrar segredos ou documentos completos.

O módulo de Secretaria precisa de finalidade, retenção, correção, anonimização quando possível, revogação de acesso, controle de anexos, backup protegido e procedimento de incidente.

## 18. Migração

1. preservar arquivo original e hash;
2. importar para staging;
3. manter aba e linha de origem;
4. normalizar sem destruir valor original;
5. gerar exceções;
6. validar totais;
7. aprovar lote;
8. importar em transação;
9. guardar reconciliação.

Registros recebem `migration_batch_id`, origem, valores original e normalizado, status e motivo de rejeição.

## 19. Operação

Ambientes separados: desenvolvimento, homologação e produção.

Obrigatório:

- backup automático;
- teste de restauração;
- migrations versionadas;
- rollback documentado;
- health checks;
- logs estruturados;
- monitoramento de API, worker e banco;
- alertas;
- rotação de segredos;
- RPO e RTO definidos antes da produção.

## 20. Testes e critérios de aceite

### Testes

- valores e arredondamento;
- transições de estado;
- permissões e isolamento entre tenants;
- timezone;
- idempotência;
- concorrência de pagamentos;
- outbox;
- estorno;
- upload privado;
- parser de tags;
- PDF;
- scheduler e FCM mockado;
- migração e reconciliação.

### Critérios

- lote aprovado reconcilia 100% dos totais da planilha;
- dois pagamentos concorrentes não ultrapassam o devido;
- repetir comando não duplica movimento;
- ciclo fechado recusa lançamento;
- saldo coincide com movimentos;
- notificação não duplica e respeita timezone;
- documento reproduz a versão publicada;
- usuário sem permissão não acessa dados pessoais;
- perda do Realtime não perde confirmação feita pela API.

## 21. Decisões bloqueadoras antes da produção

1. timezone oficial;
2. um ou vários ciclos abertos;
3. lançamentos retroativos;
4. herança do saldo inicial;
5. moeda e casas decimais;
6. permissões definitivas;
7. política de retenção LGPD;
8. push no painel web;
9. critérios de aprovação;
10. modelos documentais iniciais;
11. regra de divulgação de aniversários;
12. RPO/RTO e backup;
13. datas futuras e registros de bazar da planilha;
14. necessidade de estoque do bazar.

## 22. Critério de pronto

Uma funcionalidade só está pronta quando possui migration, contrato OpenAPI, autorização testada, tratamento de erro, auditoria adequada, testes relevantes, comportamento documentado, recuperação segura de repetição e critério de aceite demonstrável.

## 23. Estrutura de repositório e execução do projeto

O projeto deve utilizar um monorepo organizado por aplicações, módulos de domínio e infraestrutura. A estrutura abaixo é a referência oficial para implementação:

```text
tesouraria/
├── apps/
│   ├── mobile/
│   │   ├── lib/
│   │   │   ├── app/
│   │   │   ├── core/
│   │   │   ├── shared/
│   │   │   └── modules/
│   │   │       ├── auth/
│   │   │       ├── dashboard/
│   │   │       ├── congregations/
│   │   │       ├── cycles/
│   │   │       ├── finance/
│   │   │       │   ├── entries/
│   │   │       │   ├── expenses/
│   │   │       │   ├── payments/
│   │   │       │   ├── reports/
│   │   │       │   └── settings/
│   │   │       ├── notifications/
│   │   │       └── secretary/
│   │   │           ├── people/
│   │   │           ├── families/
│   │   │           ├── birthdays/
│   │   │           ├── documents/
│   │   │           └── templates/
│   │   └── test/
│   ├── api/
│   │   ├── src/
│   │   │   ├── config/
│   │   │   ├── common/
│   │   │   ├── infra/
│   │   │   └── modules/
│   │   │       ├── auth/
│   │   │       ├── tenancy/
│   │   │       ├── organizations/
│   │   │       ├── congregations/
│   │   │       ├── permissions/
│   │   │       ├── finance/
│   │   │       │   ├── cycles/
│   │   │       │   ├── entries/
│   │   │       │   ├── expenses/
│   │   │       │   ├── movements/
│   │   │       │   └── reports/
│   │   │       ├── notifications/
│   │   │       ├── secretary/
│   │   │       │   ├── people/
│   │   │       │   ├── families/
│   │   │       │   ├── birthdays/
│   │   │       │   ├── documents/
│   │   │       │   └── templates/
│   │   │       ├── audit/
│   │   │       └── files/
│   │   └── test/
│   └── worker/
│       ├── src/
│       │   ├── jobs/
│       │   ├── schedulers/
│       │   └── processors/
│       └── test/
├── packages/
│   ├── contracts/
│   ├── design_system/
│   ├── domain_types/
│   └── eslint_config/
├── supabase/
│   ├── migrations/
│   ├── seed.sql
│   ├── functions/
│   └── config.toml
├── infra/
│   ├── docker/
│   ├── ci/
│   └── monitoring/
├── docs/
│   ├── adr/
│   ├── api/
│   ├── runbooks/
│   └── manuals/
├── scripts/
│   ├── bootstrap.ps1
│   ├── bootstrap.sh
│   ├── dev.ps1
│   ├── dev.sh
│   ├── test-all.ps1
│   ├── test-all.sh
│   ├── migrate.ps1
│   └── migrate.sh
├── .env.example
├── docker-compose.yml
├── melos.yaml
├── package.json
├── pnpm-workspace.yaml
└── README.md
```

### 23.1 Regra de organização dos módulos

Cada módulo deve seguir a separação:

```text
module/
├── domain/
│   ├── entities/
│   ├── value_objects/
│   ├── repositories/
│   └── services/
├── application/
│   ├── commands/
│   ├── queries/
│   └── dto/
├── infrastructure/
│   ├── persistence/
│   ├── integrations/
│   └── mappers/
└── presentation/
    ├── controllers/
    └── validators/
```

No Flutter, a separação equivalente é:

```text
module/
├── data/
│   ├── datasources/
│   ├── models/
│   └── repositories/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── usecases/
└── presentation/
    ├── providers/
    ├── pages/
    ├── widgets/
    └── state/
```

As dependências devem apontar para dentro: apresentação depende de aplicação/domínio, nunca o contrário. Um módulo não deve importar diretamente o banco de outro módulo.

## 24. Ordem única de execução

O projeto completo deve ser executado nesta ordem:

1. configurar ferramentas e variáveis de ambiente;
2. subir PostgreSQL/Supabase local;
3. aplicar migrations;
4. aplicar seed de desenvolvimento;
5. gerar tipos e contratos;
6. instalar dependências;
7. executar lint e análise estática;
8. executar testes unitários;
9. executar testes de integração;
10. iniciar API;
11. iniciar worker;
12. iniciar Flutter;
13. executar testes end-to-end;
14. gerar documentação OpenAPI;
15. gerar artefatos de release.

Nenhuma etapa posterior deve mascarar falha de uma etapa anterior. O script deve encerrar com código diferente de zero ao primeiro erro, salvo comandos explicitamente marcados como opcionais.

### 24.1 Pré-requisitos

- Git;
- Flutter no canal estável;
- Dart compatível com a versão do Flutter;
- Node.js LTS;
- pnpm;
- Docker Desktop;
- Supabase CLI;
- Java/Android SDK para Android;
- Firebase CLI somente para tarefas de configuração;
- acesso às variáveis de ambiente de cada ambiente.

### 24.2 Variáveis de ambiente

O arquivo `.env.example` deve documentar, sem segredos reais:

```text
APP_ENV=development
API_PORT=3000
DATABASE_URL=
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
JWT_AUDIENCE=
FIREBASE_PROJECT_ID=
FIREBASE_CLIENT_EMAIL=
FIREBASE_PRIVATE_KEY=
REDIS_URL=
STORAGE_BUCKET=
APP_TIMEZONE=America/Fortaleza
```

Chaves de serviço só podem existir no backend/worker. Nunca incluir `.env`, certificados Firebase ou arquivos de produção no Git.

### 24.3 Comandos padrão

Os comandos abaixo devem existir no `README.md` e nos scripts:

```text
pnpm install
pnpm dev
pnpm lint
pnpm test
pnpm test:integration
pnpm test:e2e
pnpm db:migrate
pnpm db:seed
pnpm api:openapi
flutter pub get
flutter analyze
flutter test
flutter run
```

No Windows, `scripts/bootstrap.ps1`, `scripts/dev.ps1` e `scripts/test-all.ps1` devem ser os caminhos suportados. No Linux/macOS, usar os equivalentes `.sh`.

### 24.4 Script de execução ponta a ponta

O `scripts/bootstrap.ps1` deve:

1. validar pré-requisitos;
2. copiar `.env.example` para `.env` somente se `.env` não existir;
3. instalar dependências;
4. iniciar containers;
5. aguardar health checks;
6. aplicar migrations;
7. aplicar seed;
8. gerar contratos/tipos;
9. executar lint e testes;
10. informar os comandos de inicialização.

O script não deve sobrescrever `.env`, apagar banco, resetar dados ou executar comandos destrutivos sem uma flag explícita como `-ResetDevelopment`.

O `scripts/test-all.ps1` deve executar lint, testes unitários, integração e end-to-end, preservando logs e retornando o primeiro erro.

## 25. CI/CD e ambientes

### Ambientes

- `development`: dados descartáveis;
- `staging`: homologação com dados anonimizados;
- `production`: dados reais e acesso restrito.

Cada ambiente deve possuir projeto Supabase, Firebase, Storage, Redis e segredos separados.

### Pipeline

Pull request:

1. format;
2. lint;
3. análise estática;
4. testes unitários;
5. testes de integração;
6. verificação de migrations;
7. build do Flutter;
8. scan de dependências.

Deploy:

1. aprovar build;
2. executar backup/verificação;
3. aplicar migration compatível;
4. publicar API/worker;
5. executar smoke tests;
6. publicar Flutter;
7. monitorar erros;
8. permitir rollback documentado.

Migrations destrutivas devem ocorrer em etapas compatíveis e nunca ser aplicadas automaticamente em produção sem aprovação.

## 26. Entregáveis por módulo

Cada módulo deve entregar:

- migrations;
- entidades e regras;
- casos de uso;
- endpoints;
- OpenAPI;
- permissões;
- auditoria;
- testes;
- telas Flutter;
- estados de carregamento, vazio, erro e sucesso;
- telemetria sem dados sensíveis;
- documentação de operação;
- critérios de aceite.

## 27. Sequenciamento técnico

### Marco 1 — Fundação

Tenancy, Auth, permissões, design system, logging, erros, migrations, CI e ambientes.

### Marco 2 — Secretaria básica

Pessoas, congregações, famílias, busca, privacidade e ficha.

### Marco 3 — Documentos

Tipos, tags, templates, versionamento, prévia, PDF e validação.

### Marco 4 — Financeiro

Ciclos, tipos configuráveis, receitas, despesas, pagamentos, movimentos e saldo.

### Marco 5 — Relatórios

Dashboard, relatórios por ciclo/período e exportações.

### Marco 6 — Notificações

Tokens, preferências, aniversários, contas a vencer, worker e FCM.

### Marco 7 — Migração e lançamento

Staging, reconciliação, homologação, treinamento, rollout gradual e suporte.

O sistema pode desenvolver Secretaria e Financeiro em paralelo após o Marco 1, mas nenhum módulo deve ignorar as regras compartilhadas de tenancy, autorização, auditoria e arquivos.

## 28. Documentação operacional

O manual para usuários finais está em [MANUAL_USO_APP.md](./MANUAL_USO_APP.md). A cada release que alterar fluxo, permissão, tela, notificação ou emissão de documento, o manual deve ser revisado junto com o código.

Documentação mínima de cada release:

- notas de versão;
- migrações aplicadas;
- alterações de permissões;
- alterações de notificações;
- alterações em templates;
- instruções de rollback;
- impacto para usuários;
- evidências dos testes de aceite.
