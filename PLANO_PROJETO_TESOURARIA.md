# Plano do Projeto de Tesouraria

## 1. Objetivo

Construir um sistema multiusuário para gerenciamento financeiro de congregações, substituindo gradualmente a planilha atual por uma aplicação Flutter com:

- lançamentos de receitas e despesas;
- tipos financeiros configuráveis por congregação;
- ciclos de prestação de contas;
- saldo atualizado em tempo real;
- relatórios visuais por período e ciclo;
- aprovação e fechamento de ciclos;
- auditoria de alterações;
- notificações push configuráveis;
- importação dos dados históricos da planilha.

O sistema deve permitir que cada congregação habilite somente os recursos que utiliza. Bazar, oferta alçada, dízimo, oferta de culto, campanhas e outros tipos não devem ser módulos obrigatórios nem estruturas rígidas no código.

---

## 2. Situação atual identificada na planilha

Arquivo analisado:

`TESOURARIA - ADTCSGA EIXO DO CARRO.xlsx`

Abas encontradas:

- `RELATORIO_MENSAL`
- `Dashboard`
- `OFERTAS`
- `DÍZIMOS`
- `ALCADAS`
- `DESPESAS`
- `TIPOS_DESPESAS`
- `TIPO_RECEITA`
- `BAZAR`

### Totais identificados

Os valores abaixo são um retrato dos dados existentes e deverão ser validados antes da migração:

| Área | Registros | Total identificado |
|---|---:|---:|
| Ofertas | 51 | R$ 615,20 |
| Dízimos | 28 | R$ 7.473,54 |
| Ofertas alçadas | 30 | R$ 1.593,86 |
| Bazar | 2 | R$ 250,00 |
| Despesas previstas | 33 | R$ 4.270,14 |
| Despesas pagas | 33 | R$ 3.899,41 |
| Despesas pendentes | 33 | R$ 370,73 |

### Padrões relevantes

1. Os ciclos não seguem necessariamente o mês do calendário. Há períodos como 01/04–10/05 e 11/05–14/06.
2. As ofertas possuem diferentes meios de recebimento, como PIX e dinheiro.
3. Dízimos podem ser relacionados a uma pessoa e a um método de pagamento.
4. Uma despesa pode ser paga parcialmente e com diferentes origens financeiras.
5. Existem diferenças de maiúsculas, minúsculas, acentos e espaços em descrições e métodos.
6. Há lançamentos de bazar na aba própria e referências a bazar em `ALCADAS`.
7. Algumas despesas não possuem vencimento.
8. Existem datas futuras que precisam ser confirmadas antes da importação.
9. O dashboard depende de fórmulas e funções nomeadas, que deverão ser substituídas por regras no backend e consultas no banco.

---

## 3. Princípios do sistema

- O banco deve ser generalizado; a interface deve ser configurável.
- Nenhum tipo de receita específico deve ser obrigatório para todas as congregações.
- Lançamentos financeiros não devem ser apagados fisicamente.
- Ciclos fechados devem ser protegidos contra alterações comuns.
- Cálculos financeiros críticos devem ocorrer no backend.
- Todo lançamento deve possuir histórico de criação e alterações.
- O saldo deve ser derivado de movimentos registrados, não de valores editáveis manualmente.
- Relatórios oficiais devem ser gerados de forma consistente no backend.
- A configuração de uma congregação não deve exigir alteração no código do aplicativo.

---

## 4. Arquitetura proposta

```text
Flutter
  ├── Android
  ├── Web administrativo
  └── iOS futuro
          |
          | HTTPS / WebSocket
          v
Backend próprio
  ├── API REST
  ├── regras financeiras
  ├── autorização
  ├── fechamento e aprovação de ciclos
  ├── geração de relatórios
  ├── scheduler de notificações
  └── Firebase Admin SDK
          |
          v
Supabase
  ├── PostgreSQL
  ├── Auth
  ├── Storage
  ├── Realtime
  └── migrations e backups
          |
          v
Firebase Cloud Messaging
  └── entrega das notificações push
```

### Stack recomendada

#### Aplicação

- Flutter e Dart;
- Riverpod para estado;
- GoRouter para navegação;
- Dio para comunicação com a API;
- Freezed e `json_serializable` para modelos;
- `fl_chart` para gráficos;
- Firebase Cloud Messaging;
- Firebase Crashlytics, se aplicável ao ambiente.

#### Backend

- NestJS e TypeScript;
- API REST documentada com OpenAPI;
- WebSocket para eventos em tempo real;
- validação de entrada;
- Firebase Admin SDK;
- worker/scheduler para notificações;
- Redis e BullMQ quando houver necessidade de filas e retentativas.

#### Supabase

- PostgreSQL;
- Supabase Auth;
- Supabase Storage para comprovantes;
- Supabase Realtime;
- migrations versionadas;
- Row Level Security como camada adicional, sem substituir as regras do backend.

---

## 5. Modelo configurável por congregação

### 5.1 Organização e congregações

O sistema deve separar:

```text
Organização
  └── Congregações ou unidades
        └── Ciclos de prestação de contas
              └── Movimentos financeiros
```

Entidades principais:

- `organizations`
- `congregations`
- `users`
- `memberships`

Uma organização poderá ter uma ou várias congregações. A estrutura deve suportar essa expansão desde o início.

### 5.1.1 Login inicial da congregação

Cada congregação terá uma conta administrativa inicial própria, utilizada para ativar o ambiente e criar o primeiro usuário tesoureiro da congregação.

Fluxo:

1. a conta da congregação recebe credenciais iniciais ou convite seguro;
2. no primeiro acesso, deve trocar a senha e configurar MFA quando disponível;
3. a conta informa ou confirma os dados da congregação;
4. cria o usuário pessoal com perfil `TESOUREIRO`;
5. o tesoureiro passa a operar com login individual;
6. a conta inicial permanece restrita à ativação e à administração de usuários, conforme a política definida.

Boa prática: o login da congregação não deve ser compartilhado para os lançamentos diários. Cada pessoa deve possuir usuário individual, permitindo auditoria, revogação de acesso e recuperação de conta. A conta inicial funciona como uma conta de provisionamento da congregação, não como identidade de todos os usuários.

### 5.2 Módulos habilitados

Em vez de criar módulos fixos para bazar, alçadas ou dízimos, utilizar:

- `modules`
- `congregation_modules`

Módulos possíveis:

- receitas;
- dízimos;
- ofertas;
- ofertas alçadas;
- bazar;
- despesas;
- ciclos;
- relatórios;
- notificações;
- anexos;
- aprovações.

Cada congregação poderá ativar ou desativar módulos.

### 5.3 Tipos de movimentação

Utilizar cadastros configuráveis:

- `entry_types`
- `expense_categories`
- `payment_methods`

Exemplos de tipos de entrada:

- oferta de culto;
- dízimo;
- oferta alçada;
- bazar;
- campanha;
- evento;
- doação;
- venda de material;
- outros.

O mesmo modelo deve atender todas essas opções, sem tabelas separadas obrigatórias.

### 5.4 Campos configuráveis

Alguns tipos podem exigir informações adicionais. Para isso, utilizar:

- `entry_type_fields`
- `entry_field_values`

Exemplos:

| Tipo | Campo adicional |
|---|---|
| Dízimo | contribuinte |
| Oferta de culto | culto ou evento |
| Oferta alçada | finalidade |
| Bazar | evento ou campanha |

Cada campo pode definir:

- rótulo;
- tipo;
- obrigatoriedade;
- lista de opções;
- ordem de exibição.

---

## 6. Modelo financeiro

### 6.1 Ciclos de prestação de contas

Tabela: `accountability_cycles`

Campos sugeridos:

- `id`;
- `congregation_id`;
- `name`;
- `start_date`;
- `end_date`;
- `opening_balance`;
- `calculated_closing_balance`;
- `status`;
- `closed_at`;
- `closed_by`;
- `approved_at`;
- `approved_by`;
- `notes`.

Status:

```text
RASCUNHO
ABERTO
EM_CONFERENCIA
AGUARDANDO_APROVACAO
FECHADO
REABERTO
CANCELADO
```

O sistema deve permitir ciclos com datas personalizadas e impedir sobreposição indevida, conforme a regra definida pela organização.

### 6.2 Entradas financeiras

Tabela principal: `financial_entries`

Campos:

- `id`;
- `organization_id`;
- `congregation_id`;
- `cycle_id`;
- `entry_type_id`;
- `entry_date`;
- `description`;
- `contributor_id`, opcional;
- `total_amount`, calculado;
- `status`;
- `created_by`;
- `created_at`;
- `updated_at`.

Detalhamento por recebimento: `financial_entry_lines`

- `financial_entry_id`;
- `payment_method_id`;
- `amount`.

Assim, um único lançamento pode conter:

```text
PIX: R$ 45,00
Dinheiro: R$ 102,50
Total: R$ 147,50
```

### 6.3 Contribuintes

Tabela: `contributors`

O cadastro deve ser opcional. O sistema deve permitir:

- dízimo identificado;
- dízimo anônimo;
- histórico do nome informado no momento do lançamento;
- proteção do nome para usuários sem permissão.

### 6.4 Despesas

Tabela: `expenses`

Campos:

- `id`;
- `organization_id`;
- `congregation_id`;
- `cycle_id`;
- `description`;
- `category_id`;
- `supplier`;
- `amount_due`;
- `due_date`;
- `status`;
- `notes`;
- `created_by`.

Pagamentos: `expense_payments`

- `expense_id`;
- `paid_at`;
- `amount`;
- `funding_source`;
- `payment_method_id`;
- `created_by`;
- `notes`.

O saldo pendente será:

```text
valor pendente = valor previsto - soma dos pagamentos
```

Deve ser possível registrar vários pagamentos para a mesma despesa, inclusive com origens diferentes:

```text
Aluguel: R$ 300,00
  R$ 100,00 provenientes de ofertas
  R$ 200,00 provenientes de dízimos
```

### 6.5 Movimentos financeiros

Tabela: `financial_movements`

Cada entrada ou saída deverá gerar um movimento auditável:

- `id`;
- `congregation_id`;
- `cycle_id`;
- `direction`;
- `source_type`;
- `source_id`;
- `amount`;
- `occurred_at`;
- `description`;
- `created_by`.

Fórmula básica:

```text
saldo final =
saldo inicial
+ total de entradas
- total de saídas
+ ajustes autorizados
```

---

## 7. Usuários e permissões

Perfis iniciais:

- administrador;
- tesoureiro;
- auxiliar financeiro;
- conferente;
- responsável/aprovador;
- visualizador;
- auditor.

Permissões específicas:

- lançar receita;
- editar receita;
- lançar despesa;
- registrar pagamento;
- visualizar dados sensíveis;
- fechar ciclo;
- aprovar ciclo;
- reabrir ciclo;
- configurar módulos;
- gerenciar usuários;
- exportar relatórios.

As permissões devem ser aplicadas no backend. A ocultação de telas no Flutter não é suficiente para proteger os dados.

---

## 8. Notificações push

### 8.1 Objetivo

Notificar usuários sobre contas próximas do vencimento, contas vencidas, ciclos e aprovações, com configuração desde quando os alertas devem começar.

Exemplo:

```text
Despesa: Aluguel
Vencimento: 20/10/2026
Começar a notificar: 10 dias antes
Horário: 08:00
Frequência: diariamente
Parar quando: totalmente paga
```

### 8.2 Configurações

Configuração por congregação:

- notificações ativas;
- dias de antecedência;
- horário de envio;
- notificar no vencimento;
- repetir após o vencimento;
- intervalo de repetição;
- valor mínimo;
- tipos de despesas;
- usuários destinatários.

Configuração por usuário:

- receber ou não push;
- contas a vencer;
- contas vencidas;
- ciclos;
- aprovações;
- horário silencioso;
- congregações acompanhadas.

Configuração por despesa:

- ativar ou desativar;
- antecedência personalizada;
- horário personalizado;
- repetição;
- parar quando paga;
- destinatários específicos.

### 8.3 Estrutura de dados

Tabelas:

- `notification_settings`;
- `user_notification_preferences`;
- `expense_notification_rules`;
- `device_tokens`;
- `notifications`.

### 8.4 Fluxo técnico

1. O Flutter solicita o token FCM.
2. O token é enviado ao backend.
3. O backend armazena o dispositivo no Supabase.
4. Um scheduler busca despesas pendentes.
5. O scheduler avalia as regras de notificação.
6. O backend envia pelo Firebase Admin SDK.
7. O resultado é gravado em `notifications`.
8. Tokens inválidos são desativados.
9. O clique na notificação abre a despesa ou o ciclo correspondente.

O Flutter nunca deve conter a chave privada do Firebase.

### 8.5 Prevenção de duplicidade

Usar uma chave idempotente baseada em:

```text
despesa + usuário + tipo de alerta + data programada
```

O sistema também deve registrar tentativas, erros e retentativas.

### 8.6 Tipos de alerta

- conta próxima do vencimento;
- conta vencida;
- pagamento confirmado;
- ciclo próximo do encerramento;
- ciclo aguardando conferência;
- ciclo aguardando aprovação;
- ciclo aprovado;
- ciclo reaberto;
- divergência no fechamento.

---

## 9. Relatórios e dashboard

### Dashboard

Exibir somente os blocos habilitados para a congregação:

- saldo atual;
- saldo do ciclo;
- receitas por tipo;
- dízimos;
- ofertas;
- bazar;
- despesas pagas;
- despesas pendentes;
- contas vencidas;
- contas próximas do vencimento;
- evolução do saldo;
- comparação com ciclos anteriores.

### Relatórios

Filtros:

- congregação;
- ciclo;
- período;
- tipo de receita;
- método de pagamento;
- categoria de despesa;
- status;
- usuário;
- contribuinte, conforme permissão.

Relatórios iniciais:

1. prestação de contas por ciclo;
2. receitas por período;
3. despesas por período;
4. contas a vencer;
5. contas vencidas;
6. pagamentos por origem;
7. evolução do saldo;
8. auditoria;
9. divergências de fechamento.

O Flutter exibirá os dados e filtros. O backend será responsável por gerar os PDFs, CSVs e XLSX oficiais.

---

## 10. Fluxos principais

### Lançamento de receita

1. Selecionar congregação.
2. Selecionar ciclo aberto.
3. Selecionar tipo de entrada.
4. Preencher os campos configurados.
5. Informar os valores por método de pagamento.
6. Anexar comprovante, se exigido.
7. Confirmar.
8. Backend validar e gravar.
9. Atualizar saldo e dashboard.

### Lançamento de despesa

1. Selecionar ciclo.
2. Informar descrição e categoria.
3. Informar valor previsto.
4. Informar vencimento.
5. Registrar pagamento total ou parcial.
6. Informar origem dos recursos.
7. Anexar comprovante.
8. Atualizar pendência e notificações.

### Fechamento de ciclo

1. Tesoureiro solicita fechamento.
2. Sistema verifica pendências e inconsistências.
3. Conferente revisa os lançamentos.
4. Responsável aprova.
5. Sistema bloqueia alterações comuns.
6. Gera relatório final.
7. Registra aprovação e auditoria.

---

## 11. Auditoria e integridade

Criar histórico para:

- criação;
- alteração;
- cancelamento;
- estorno;
- aprovação;
- reabertura;
- alteração de configuração.

Cada registro deve conter:

- usuário;
- data e hora;
- operação;
- valores anterior e novo;
- motivo;
- origem da requisição, quando necessário.

Não excluir lançamentos financeiros fisicamente. Utilizar cancelamento ou estorno.

Regras adicionais:

- impedir pagamento acima do permitido, salvo ajuste autorizado;
- impedir lançamentos em ciclo fechado;
- usar idempotência em operações de gravação;
- validar organização e congregação em todas as requisições;
- proteger dados de contribuintes;
- manter transações atômicas para lançamento e atualização de saldo.

---

## 12. Migração da planilha

Não importar diretamente para as tabelas finais.

### Etapas

1. Fazer cópia de segurança da planilha.
2. Criar tabelas de staging.
3. Importar cada aba.
4. Corrigir codificação e acentos.
5. Padronizar métodos de pagamento.
6. Padronizar categorias e descrições.
7. Mapear cada aba para tipos generalizados.
8. Detectar duplicidades.
9. Validar datas fora do período esperado.
10. Conferir totais com a planilha.
11. Importar dados aprovados.
12. Gerar relatório de rejeições e ajustes.

### Mapeamento

| Aba atual | Destino |
|---|---|
| `OFERTAS` | `financial_entries` com tipo Oferta de culto |
| `DÍZIMOS` | `financial_entries` com tipo Dízimo |
| `ALCADAS` | `financial_entries` com tipo Oferta alçada ou Bazar, conforme validação |
| `BAZAR` | `financial_entries` com tipo Bazar |
| `DESPESAS` | `expenses` e `expense_payments` |
| `TIPO_RECEITA` | `entry_types` |
| `TIPOS_DESPESAS` | `expense_categories` |
| `Dashboard` | não importar como dados; recriar por consultas |
| `RELATORIO_MENSAL` | não importar como dados; recriar por relatórios |

### Pontos que precisam de validação

- registros de bazar presentes em `ALCADAS`;
- datas futuras até 2029;
- descrições duplicadas com grafia diferente;
- métodos `PIX`, `pix`, `DINHEIRO` e `especie`;
- despesas sem vencimento;
- diferença entre valor previsto, pago e pendente;
- significado do campo `SALVA`.

---

## 13. Fases de desenvolvimento

### Fase 1 — Descoberta e regras

- validar os fluxos atuais;
- responder as decisões pendentes;
- definir papéis;
- validar conceitos de ciclo;
- definir política de fechamento;
- elaborar regras financeiras.

### Fase 2 — Fundação técnica

- criar repositórios;
- configurar Flutter;
- configurar backend;
- configurar Supabase;
- configurar Firebase;
- criar ambientes de desenvolvimento, homologação e produção;
- configurar migrations, logs e CI.

### Fase 3 — Cadastros e configuração

- organização;
- congregações;
- usuários;
- permissões;
- módulos;
- tipos de entrada;
- campos configuráveis;
- categorias;
- métodos de pagamento;
- contribuintes.

### Fase 4 — Operação financeira

- ciclos;
- receitas;
- pagamentos por método;
- despesas;
- pagamentos parciais;
- movimentos financeiros;
- comprovantes;
- estornos.

### Fase 5 — Fechamento e auditoria

- conferência;
- aprovação;
- fechamento;
- bloqueio;
- reabertura autorizada;
- histórico de alterações.

### Fase 6 — Dashboard e relatórios

- dashboard configurável;
- relatórios por ciclo;
- relatórios por período;
- gráficos;
- PDF;
- CSV;
- XLSX.

### Fase 7 — Notificações

- tokens dos dispositivos;
- preferências;
- regras por despesa;
- scheduler;
- Firebase Admin SDK;
- histórico;
- retentativas;
- deep links.

### Fase 8 — Migração e homologação

- staging;
- importação;
- conferência dos totais;
- testes com usuários reais;
- comparação com a planilha;
- correção dos dados;
- treinamento;
- entrada em produção.

---

## 14. MVP recomendado

O primeiro lançamento deve conter:

1. login;
2. usuários e permissões;
3. congregações;
4. módulos configuráveis;
5. tipos de receita configuráveis;
6. ciclos personalizados;
7. ofertas;
8. dízimos;
9. ofertas alçadas;
10. bazar como tipo de receita;
11. despesas;
12. pagamentos parciais;
13. saldo em tempo real;
14. dashboard;
15. relatório por ciclo;
16. fechamento e aprovação;
17. auditoria;
18. notificações de contas a vencer;
19. importação da planilha.

Recursos como estoque completo do bazar, contabilidade de partidas dobradas, integração bancária e conciliação automática podem ficar para versões posteriores.

---

## 15. Perguntas para decisão

### Congregações e estrutura

1. O sistema será usado por uma única organização ou por várias organizações independentes?
2. Cada congregação terá saldo separado?
3. Haverá um saldo consolidado da organização?
4. Uma pessoa poderá atuar em mais de uma congregação?

Decisões específicas do login inicial:

- O login inicial da congregação será um e-mail institucional ou outro identificador?
- A conta inicial continuará ativa após a criação do tesoureiro ou será convertida em administrador da congregação?
- Será obrigatório criar ao menos um usuário pessoal tesoureiro antes de liberar lançamentos?

### Ciclos

5. Pode existir mais de um ciclo aberto simultaneamente?
6. Quem poderá fechar e aprovar um ciclo?
7. O saldo inicial será herdado automaticamente do ciclo anterior?
8. Um ciclo fechado poderá ser reaberto?

### Tipos financeiros

9. Bazar será inicialmente apenas um tipo de receita ou precisará de estoque e produtos?
10. Oferta alçada terá finalidades configuráveis?
11. Será obrigatório identificar o culto ou evento das ofertas?
12. Dízimos anônimos serão permitidos?
13. Quais tipos de receita devem ser criados no primeiro cadastro?

### Despesas

14. Despesas futuras devem reduzir o saldo projetado ou somente aparecer como compromisso?
15. Será permitido pagar acima do valor previsto?
16. Pagamentos exigirão aprovação?
17. Todas as despesas exigirão comprovante?

### Notificações

18. O padrão inicial deve ser quantos dias antes do vencimento?
19. A notificação deve repetir diariamente após o vencimento?
20. Quem receberá os alertas: tesoureiro, administrador, responsável pela despesa ou todos?
21. Haverá horário silencioso?
22. Também serão enviados alertas por e-mail ou somente push?

### Migração

23. Os dados históricos completos devem ser importados?
24. As datas até 2029 estão corretas?
25. Os lançamentos de bazar em `ALCADAS` são duplicados ou devem ser preservados?
26. A planilha continuará sendo utilizada durante a implantação?

---

## 16. Decisões recomendadas

Para reduzir risco, recomenda-se:

- Flutter para Android e painel web autenticado;
- backend próprio em NestJS com adaptador Express;
- Supabase como PostgreSQL, Auth, Storage e Realtime;
- Firebase Cloud Messaging apenas para entrega push;
- configuração por congregação;
- tipos financeiros generalizados;
- pagamentos separados das despesas;
- ciclos com datas personalizadas;
- fechamento com aprovação;
- auditoria obrigatória;
- relatórios oficiais gerados pelo backend;
- scheduler de notificações no backend;
- importação em duas etapas com staging e validação.

O ponto central do projeto é separar o **modelo financeiro generalizado** da **configuração específica de cada congregação**. Dessa forma, novas congregações poderão utilizar conjuntos diferentes de recursos sem exigir alterações na estrutura do banco ou no código principal do aplicativo.

---

## 17. Projeto de Secretaria

Além do módulo financeiro, o sistema deverá possuir um módulo de Secretaria para administrar membros, famílias, aniversários e documentos oficiais da congregação.

O módulo de Secretaria deve ser independente do financeiro, mas compartilhar:

- organização;
- congregação;
- usuários;
- permissões;
- auditoria;
- notificações;
- armazenamento de arquivos;
- configurações gerais.

Uma congregação poderá utilizar Financeiro, Secretaria ou ambos, conforme seus módulos habilitados.

### 17.1 Objetivos

- manter cadastro atualizado de membros;
- organizar membros por congregação, família e situação;
- localizar rapidamente dados cadastrais;
- emitir ficha individual do membro;
- emitir certificados e declarações;
- cadastrar novos modelos de documentos pelo administrador;
- enviar notificações de aniversariantes;
- controlar acesso a dados pessoais;
- preservar histórico das alterações.

---

## 18. Gestão de membros

### 18.1 Cadastro de pessoas

Tabela sugerida: `people`

Campos iniciais:

- `id`;
- `organization_id`;
- `full_name`;
- `preferred_name`;
- `social_name`, se aplicável;
- `birth_date`;
- `gender`, se a organização optar por utilizar;
- `email`;
- `phone`;
- `whatsapp`;
- `document_number`, opcional e protegido;
- `marital_status`;
- `occupation`;
- `photo_url`;
- `notes`;
- `created_at`;
- `updated_at`.

Dados sensíveis devem possuir proteção adicional e não devem aparecer para perfis sem permissão.

### 18.2 Vínculo com a congregação

Tabela sugerida: `congregation_memberships`

Campos:

- `person_id`;
- `congregation_id`;
- `membership_status`;
- `membership_date`;
- `baptism_date`, opcional;
- `transfer_date`, opcional;
- `role`;
- `ministerial_function`, opcional;
- `is_active`;
- `notes`.

Situações possíveis:

```text
VISITANTE
CONGREGADO
MEMBRO
TRANSFERIDO
INATIVO
AFASTADO
FALECIDO
```

Os status devem ser configuráveis, caso a organização use uma nomenclatura própria.

### 18.3 Famílias

Tabelas sugeridas:

- `families`;
- `family_members`.

Recursos:

- criar grupo familiar;
- relacionar responsáveis;
- relacionar cônjuges;
- relacionar filhos;
- cadastrar endereço compartilhado;
- manter contatos individuais;
- emitir ficha familiar;
- filtrar aniversariantes por família.

O parentesco não deve ser inferido apenas pelo sobrenome. Deve ser mantido explicitamente quando essa informação for relevante.

### 18.4 Histórico da pessoa

Para preservar o histórico, alterações importantes devem gerar registros em:

- `member_history`;
- `membership_events`.

Exemplos:

- entrada na congregação;
- batismo;
- mudança de congregação;
- alteração de situação;
- participação em ministério;
- emissão de certificado;
- atualização cadastral.

---

## 19. Ficha de membro

O sistema deverá permitir emitir uma ficha individual ou familiar em PDF.

### Conteúdo configurável

- dados pessoais;
- foto;
- contatos;
- endereço;
- dados familiares;
- situação na congregação;
- datas relevantes;
- observações autorizadas;
- histórico resumido;
- QR Code de validação, se necessário;
- assinatura e identificação da congregação.

O administrador deve poder escolher quais campos aparecem na ficha, respeitando as permissões e a finalidade do documento.

### Cuidados

- não incluir dados financeiros na ficha sem autorização explícita;
- aplicar máscara em documentos pessoais;
- registrar quem emitiu;
- registrar data e versão do modelo utilizado;
- permitir invalidar uma ficha emitida, sem apagar o histórico;
- controlar quem pode baixar ou compartilhar o arquivo.

---

## 20. Certificados, declarações e documentos

O sistema deve suportar modelos como:

- certificado de apresentação infantil;
- certificado de batismo;
- certificado de casamento, se aplicável;
- carta ou certificado de apresentação;
- declaração de membro;
- declaração de participação;
- ficha de membro;
- comprovante de transferência;
- outros modelos definidos pelo administrador.

O objetivo é que novos documentos possam ser cadastrados sem alterar o código do aplicativo.

### 20.1 Catálogo de documentos

Tabela: `document_types`

Campos:

- `id`;
- `organization_id`;
- `name`;
- `code`;
- `description`;
- `document_category`;
- `active`;
- `requires_approval`;
- `available_for_congregations`;
- `created_by`.

### 20.2 Modelos e versões

Tabelas:

- `document_templates`;
- `document_template_versions`.

Cada modelo deve possuir:

- nome;
- tipo de documento;
- congregação ou escopo global;
- status;
- versão;
- conteúdo do modelo;
- configuração visual;
- data de publicação;
- autor;
- aprovador;
- data de aprovação.

Status recomendados:

```text
RASCUNHO
EM_REVISAO
APROVADO
PUBLICADO
ARQUIVADO
```

Uma versão publicada não deve ser sobrescrita. Alterações devem criar uma nova versão para preservar a reprodução exata de documentos antigos.

---

## 21. Padrão de mercado para modelos personalizados

### 21.1 Abordagem recomendada

Usar modelos baseados em HTML e CSS controlados pelo backend, com tags aprovadas e uma camada de renderização para PDF.

Fluxo:

```text
Administrador cria ou edita modelo
          |
          v
Sistema valida tags e permissões
          |
          v
Pré-visualização com dados de exemplo
          |
          v
Revisão/aprovação
          |
          v
Publicação da versão
          |
          v
Backend gera PDF com os dados reais
```

Essa abordagem é mais flexível para certificados e fichas do que montar o layout apenas com widgets Flutter. O Flutter será utilizado para o editor, a configuração e a pré-visualização; a emissão oficial ficará no backend.

### 21.2 Editor de modelos

O administrador poderá:

- escolher um modelo-base;
- editar textos;
- definir fontes, cores e alinhamentos;
- inserir logo;
- inserir assinatura;
- posicionar campos;
- configurar cabeçalho e rodapé;
- definir tamanho da página;
- escolher orientação retrato ou paisagem;
- usar bordas, tabelas e imagens;
- visualizar uma prévia;
- publicar uma versão aprovada.

Para a primeira versão, recomenda-se iniciar com blocos controlados:

- texto;
- título;
- imagem;
- tabela;
- assinatura;
- linha;
- campo dinâmico;
- quebra de página.

Um editor visual completamente livre pode ser incluído posteriormente, caso seja realmente necessário.

### 21.3 Tags dinâmicas

As tags devem ser escolhidas em um catálogo, e não digitadas livremente sem validação.

Exemplos:

```text
{{pessoa.nome_completo}}
{{pessoa.nome_preferido}}
{{pessoa.data_nascimento}}
{{pessoa.documento_mascarado}}
{{pessoa.endereco}}
{{pessoa.telefone}}
{{familia.nome}}
{{membro.data_entrada}}
{{membro.data_batismo}}
{{congregacao.nome}}
{{congregacao.endereco}}
{{documento.numero}}
{{documento.data_emissao}}
{{usuario.emissor_nome}}
```

Tags de lista ou condição podem ser suportadas em uma segunda etapa:

```text
{{#if pessoa.data_batismo}}
Data de batismo: {{pessoa.data_batismo}}
{{/if}}
```

O mecanismo de templates deve impedir execução de código, consultas arbitrárias ou comandos inseridos no conteúdo do administrador. Somente tags registradas e autorizadas podem ser processadas.

### 21.4 Regras para documentos oficiais

- validar tags antes da publicação;
- mostrar campos obrigatórios ausentes na prévia;
- impedir publicação de modelo inválido;
- exigir aprovação quando configurado;
- numerar documentos emitidos;
- registrar versão utilizada;
- guardar hash do arquivo final;
- permitir consulta por código de validação;
- permitir cancelamento ou revogação;
- manter histórico de emissões.

Tabelas sugeridas:

- `document_issued`;
- `document_issued_fields`;
- `document_signatures`;
- `document_validation_tokens`.

### 21.5 Assinaturas e validação

Na primeira versão, o sistema pode utilizar:

- nome do responsável;
- cargo;
- imagem de assinatura;
- data de emissão;
- código único de validação;
- QR Code direcionando para uma página autenticada ou pública de validação limitada.

Assinatura digital com validade jurídica deve ser tratada como um projeto específico, pois pode exigir certificado digital, provedor especializado e requisitos legais.

---

## 22. Notificações de aniversariantes

O sistema deverá enviar notificações no dia do aniversário e, opcionalmente, produzir listas antecipadas.

### Configurações por congregação

- habilitar ou desabilitar aniversários;
- horário de envio;
- enviar no dia;
- enviar com antecedência;
- enviar resumo diário;
- enviar resumo semanal;
- destinatários;
- incluir visitantes ou apenas membros ativos;
- respeitar membros que não autorizaram divulgação.

### Exemplos

Notificação no dia:

```text
Aniversariantes de hoje

Hoje é aniversário de:
- Maria Silva
- João Souza
```

Alerta antecipado para a secretaria:

```text
Aniversários dos próximos 7 dias

Consulte a lista para organizar os cumprimentos da congregação.
```

### Privacidade

O membro deve poder ter sua data de nascimento:

- visível apenas para a secretaria;
- utilizada para notificações internas;
- omitida de listas públicas;
- completamente restrita, conforme política da organização.

Não se deve expor o ano de nascimento quando ele não for necessário.

### Implementação

O mesmo serviço de notificações push utilizado para contas a vencer pode processar aniversários. O scheduler deverá:

1. buscar aniversariantes elegíveis;
2. considerar congregação e status;
3. verificar preferências e horário;
4. evitar duplicidade;
5. enviar pelo Firebase Admin SDK;
6. registrar o resultado;
7. respeitar opt-out e horário silencioso.

---

## 23. Permissões da Secretaria

Permissões sugeridas:

- visualizar cadastro;
- criar pessoa;
- editar cadastro;
- visualizar dados sensíveis;
- gerenciar famílias;
- alterar situação de membro;
- emitir ficha;
- emitir certificado;
- cancelar documento;
- criar modelo;
- revisar modelo;
- publicar modelo;
- gerenciar notificações;
- exportar lista de aniversariantes.

Exemplo:

```text
Secretário:
- cadastra e atualiza membros
- emite documentos publicados

Responsável da secretaria:
- aprova documentos
- publica modelos
- acessa relatórios da secretaria

Administrador:
- configura tudo

Visualizador:
- consulta apenas dados autorizados
```

---

## 24. Relatórios da Secretaria

Relatórios iniciais:

- membros ativos por congregação;
- membros por situação;
- aniversariantes do dia;
- aniversariantes por período;
- famílias;
- novos membros;
- transferências;
- membros sem dados obrigatórios;
- documentos emitidos;
- documentos cancelados;
- histórico de alterações;
- lista para impressão ou exportação.

Os relatórios devem respeitar a proteção de dados e as permissões do usuário.

---

## 25. LGPD e proteção de dados

O módulo de Secretaria armazenará dados pessoais e deve seguir princípios de proteção de dados.

Medidas necessárias:

- coletar somente dados necessários;
- definir finalidade dos campos;
- controlar acesso por perfil;
- mascarar documentos pessoais;
- registrar acesso a dados sensíveis;
- permitir correção cadastral;
- definir política de retenção;
- controlar anexos;
- criptografar dados sensíveis quando necessário;
- documentar consentimento ou base legal aplicável;
- permitir desativar o uso da data de aniversário para divulgação;
- evitar exposição pública de listas nominais sem autorização.

---

## 26. Fases adicionais do projeto

As fases anteriores permanecem válidas. Para a Secretaria, acrescentar:

### Fase S1 — Modelagem cadastral

- pessoas;
- membros;
- congregações;
- famílias;
- situações;
- históricos;
- permissões.

### Fase S2 — Cadastro e ficha

- cadastro individual;
- cadastro familiar;
- pesquisa;
- filtros;
- ficha de membro;
- exportação controlada.

### Fase S3 — Documentos

- catálogo de tipos;
- modelos;
- tags;
- versões;
- pré-visualização;
- aprovação;
- emissão em PDF;
- numeração;
- validação por código ou QR Code.

### Fase S4 — Aniversários

- preferências;
- lista diária;
- notificações push;
- resumo semanal;
- regras de privacidade.

### Fase S5 — Homologação da Secretaria

- validar fichas;
- validar certificados;
- testar tags ausentes;
- testar publicação de versões;
- testar permissões;
- testar cancelamento;
- testar notificações;
- conferir proteção dos dados.

---

## 27. MVP ampliado

Além do MVP financeiro, o primeiro lançamento da Secretaria pode conter:

1. cadastro de pessoas;
2. vínculo com congregação;
3. situação do membro;
4. famílias;
5. pesquisa e filtros;
6. ficha de membro em PDF;
7. catálogo de documentos;
8. modelos com tags aprovadas;
9. versionamento;
10. pré-visualização;
11. certificado de apresentação infantil;
12. emissão com numeração;
13. histórico de documentos;
14. aniversariantes do dia;
15. notificações push configuráveis;
16. permissões específicas;
17. auditoria;
18. controles básicos de privacidade.

Recursos posteriores:

- editor visual avançado;
- assinatura digital qualificada;
- portal público de validação;
- integração com WhatsApp;
- agenda de cultos e eventos;
- presença;
- controle de classes;
- histórico pastoral ampliado.

---

## 29. Lacunas e riscos que devem ser resolvidos antes da implementação

O plano funcional não deve ser convertido diretamente em código sem as definições abaixo. Elas representam pontos que poderiam quebrar o aplicativo, gerar saldos incorretos, expor dados ou impedir a recuperação de falhas.

### 29.1 Isolamento e identidade

- Toda requisição deve validar `organization_id` e `congregation_id` no backend; nunca confiar nesses valores vindos do Flutter.
- O JWT do Supabase Auth deve ser validado quanto a emissor, audiência, expiração e usuário ativo.
- O papel, a congregação e as permissões devem ser derivados da associação autenticada.
- Toda consulta, relatório, anexo, notificação e documento deve aplicar o mesmo isolamento de tenant.
- RLS deve ser testado com usuários da mesma congregação, de outra congregação, de outra organização e usuários desativados.

### 29.2 Dinheiro, datas e ciclos

- Armazenar valores como `numeric(19,4)` ou centavos inteiros; nunca usar `float`.
- Definir moeda, arredondamento, escala, limites e rejeição de valores negativos.
- Definir timezone por organização; datas de negócio são locais e auditoria/envio são UTC.
- Definir se haverá um ou vários ciclos abertos, se ciclos podem se sobrepor e como tratar lançamentos retroativos.
- Definir herança do saldo inicial e o comportamento do primeiro ciclo.
- Definir se despesa pertence ao ciclo pela data de competência, vencimento ou pagamento.

### 29.3 Integridade e concorrência

- `funding_source` deve referenciar uma origem configurada, não ser texto livre.
- Cada receita, pagamento, estorno ou cancelamento deve gerar movimentos financeiros de forma atômica.
- Movimentos são imutáveis; correções usam estorno e novo lançamento.
- Comandos mutáveis devem aceitar chave de idempotência.
- Fechamento, aprovação e pagamentos devem usar lock transacional ou controle otimista por versão.
- O cliente nunca informa saldo final e não pode sobrescrever alterações concorrentes silenciosamente.

### 29.4 Offline, anexos e notificações

- O MVP deve ser offline-first: permitir consulta e lançamentos autorizados offline, gravar em SQLite local e sincronizar automaticamente quando a internet retornar.
- Operações offline devem possuir fila, idempotency key, dependências, tentativas e estados visíveis.
- Aprovação final, fechamento de ciclo, publicação de template e emissão oficial de PDF devem aguardar sincronização com o servidor.
- Conflitos financeiros não podem ser resolvidos automaticamente pela última gravação; devem exigir revisão autorizada.
- Comprovantes serão armazenados no Cloudinary em pastas privadas por congregação, com limite, MIME permitido, `public_id` gerado pelo servidor e URL assinada com expiração.
- O backend deve gerar a assinatura do Cloudinary; `CLOUDINARY_API_SECRET` nunca pode chegar ao Flutter.
- O lançamento pode ser feito offline: foto/documento fica na fila local e é enviado ao Cloudinary após a reconexão.
- Notificações precisam de timezone, janela silenciosa, deduplicação, retentativa, expiração de tokens e tratamento de múltiplos dispositivos.
- Eventos assíncronos devem usar outbox; uma falha no FCM não pode desfazer um lançamento financeiro.
- Se o painel web receber push, FCM Web e suas credenciais precisam ser definidos separadamente.

### 29.5 Templates, Secretaria e LGPD

- Templates aceitam somente tags e blocos autorizados; não podem executar JavaScript, SQL, HTML arbitrário ou consultas livres.
- Versões publicadas são imutáveis e devem ser registradas em cada documento emitido.
- Pessoas homônimas não podem ser identificadas somente pelo nome; duplicidade deve ser alerta, não exclusão automática.
- Data de nascimento, documentos e fichas exigem permissões específicas e política de retenção.
- Deve existir política de correção, anonimização, revogação de acesso, backup e resposta a incidentes.

### 29.6 Operação e aceite

- Definir ambientes, migrations, rollback, backup, restauração, RPO, RTO, monitoramento e rotação de segredos.
- Cada endpoint precisa de contrato OpenAPI, códigos de erro e testes de autorização.
- O MVP deve testar isolamento entre tenants, concorrência, idempotência, reconciliação com a planilha, notificações sem duplicidade e reprodução de documentos por versão.

### 29.7 Diretrizes de interface

- Utilizar o Material Design por meio do Material 3 do Flutter.
- Manter uma interface minimalista, com poucos elementos por tela, hierarquia visual clara e ações principais destacadas.
- Projetar para usuários leigos: linguagem cotidiana, rótulos explícitos, exemplos nos campos, valores padrão seguros e nenhuma dependência de conhecimento contábil ou técnico.
- Aplicar divulgação progressiva: mostrar primeiro as tarefas essenciais e revelar opções avançadas somente quando necessárias ou autorizadas.
- Separar claramente o modo operacional do modo de gestão/configuração. Configurações avançadas não devem aparecer misturadas aos lançamentos cotidianos.
- Usar assistentes passo a passo para ciclos, primeiro lançamento, emissão de documentos e configurações complexas.
- Exibir sempre contexto antes de uma ação: congregação, ciclo, período, status e impacto esperado.
- Confirmar ações irreversíveis ou sensíveis com resumo legível, motivo e permissão adequada.
- Oferecer ajuda contextual, textos curtos de orientação, estados vazios explicativos e mensagens de erro com solução.
- Não exigir que o usuário conheça códigos internos, nomes de tabelas, termos técnicos ou regras de banco de dados.
- Usar componentes nativos e acessíveis: `Scaffold`, `AppBar`, `NavigationBar`, `NavigationRail`, `Card`, `DataTable`, `Form`, `Dialog`, `SnackBar` e `Banner`, conforme a plataforma.
- Implementar `RefreshIndicator` nas telas com listas ou dashboard rolável para permitir puxar a tela para baixo e atualizar os dados.
- O gesto de atualização deve mostrar estado de carregamento, sucesso ou erro; não pode apagar dados já exibidos em caso de falha.
- A atualização manual complementa o Realtime. O aplicativo deve atualizar automaticamente quando receber evento e permitir atualização manual quando o usuário desejar.
- Em telas web/desktop sem gesto de toque, disponibilizar botão ou ação de atualizar equivalente.
- Respeitar acessibilidade, contraste, tamanho mínimo de toque, teclado, leitores de tela e responsividade.
- Evitar excesso de cores, gráficos e campos na tela inicial; priorizar saldo, pendências, ações rápidas e alertas.

## 28. Perguntas adicionais da Secretaria

1. O cadastro deverá abranger somente membros ou também visitantes, congregados e crianças?
2. A mesma pessoa poderá estar vinculada a mais de uma congregação?
3. Quais situações de membro devem existir inicialmente?
4. Quais campos são obrigatórios na ficha de cadastro?
5. A data de nascimento será obrigatória ou opcional?
6. O membro poderá solicitar correção dos próprios dados?
7. Quem poderá visualizar documentos pessoais e data completa de nascimento?
8. O aniversário será divulgado para toda a congregação ou somente para usuários autorizados?
9. A notificação deve mencionar apenas o nome ou também a idade?
10. A apresentação infantil terá numeração sequencial por congregação ou global?
11. O certificado precisa de assinatura de uma ou duas autoridades?
12. A assinatura será imagem cadastrada ou assinatura digital?
13. Quais modelos devem existir no primeiro lançamento?
14. O administrador poderá editar o layout livremente ou começará com blocos padronizados?
15. Quais tags são necessárias para cada modelo?
16. Haverá validação pública por QR Code?
17. Documentos cancelados continuarão consultáveis para auditoria?
18. Será necessário enviar documentos por e-mail ou WhatsApp?
19. A ficha familiar terá o mesmo modelo para todas as congregações?
20. Existem requisitos legais ou denominacionais específicos para os certificados?

---

## 30. Documentos de execução

O SDD técnico está em [SDD_PROJETO_TESOURARIA_SECRETARIA.md](./SDD_PROJETO_TESOURARIA_SECRETARIA.md) e deve ser utilizado como referência obrigatória para a implementação, organização do monorepo, execução ponta a ponta, ambientes, CI/CD, testes e critérios de pronto.

O manual operacional está em [MANUAL_USO_APP.md](./MANUAL_USO_APP.md) e deve acompanhar o treinamento dos usuários e a homologação dos fluxos de Tesouraria e Secretaria.
