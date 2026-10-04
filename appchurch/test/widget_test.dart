import 'package:appchurch/core/local/app_database.dart';
import 'package:appchurch/features/members/birthdays_page.dart';
import 'package:appchurch/main.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api_client.dart';

const _cycleOpen = {
  'id': 'c-open',
  'startDate': '2026-09-14',
  'endDate': '2026-10-11',
  'status': 'OPEN',
};
const _cycleClosed = {
  'id': 'c-closed',
  'startDate': '2026-08-10',
  'endDate': '2026-09-13',
  'status': 'CLOSED',
};

const _dashboard = {
  'cycles': [_cycleOpen, _cycleClosed],
  'cycle': _cycleOpen,
  'funds': {
    'OFERTAS_CULTO': {
      'opening': 35.27,
      'revenue': 48.1,
      'expenses': 16,
      'closing': 67.37,
    },
    'OFERTAS_ALCADAS': {
      'opening': 561.34,
      'revenue': 430.74,
      'expenses': 972.69,
      'closing': 19.39,
    },
    'DIZIMOS': {'opening': 0, 'revenue': 363, 'expenses': 0, 'closing': 363},
  },
  'tithe': {
    'gross': 363,
    'expenses': 0,
    'leaderPercentage': 20,
    'leaderAmount': 72.6,
    'headquartersAmount': 290.4,
    'balanceBeforeTransfers': 363,
    'headquartersNegative': false,
  },
  'transfers': [
    {'destinationName': 'Dirigente', 'amount': 72.6, 'status': 'PREVISTO'},
    {'destinationName': 'Igreja sede', 'amount': 290.4, 'status': 'PREVISTO'},
  ],
  'revenueByCategory': [
    {
      'fundCode': 'OFERTAS_ALCADAS',
      'category': 'Oferta alçada',
      'amount': 180.74,
    },
    {'fundCode': 'OFERTAS_ALCADAS', 'category': 'Bazar', 'amount': 250},
  ],
  'pendingPayables': [
    {
      'description': 'CAGECE SET/2026',
      'dueDate': '2099-12-31',
      'remaining': 50.73,
      'overdue': false,
    },
  ],
};

const _members = [
  {
    'id': 'm1',
    'full_name': 'Ana Souza',
    'birth_date': '1990-10-04',
    'ministry_role': 'MEMBRO',
  },
  {
    'id': 'm2',
    'full_name': 'Bruno Lima',
    'birth_date': '1985-03-12',
    'ministry_role': 'DIÁCONO',
  },
];

void main() {
  late AppDatabase database;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() => database.close());

  FakeApiClient api({bool connected = true}) => FakeApiClient(
    database: database,
    connected: connected,
    responses: {
      'finance/dashboard': _dashboard,
      'finance/members': _members,
      'finance/expense-categories': [
        {'id': 'cat-aluguel', 'name': 'ALUGUEL'},
        {'id': 'cat-cagece', 'name': 'CAGECE'},
      ],
      'finance/revenue-categories': [
        {
          'id': 'rc-bazar',
          'code': 'BAZAR',
          'name': 'Bazar',
          'fundCode': 'OFERTAS_ALCADAS',
        },
        {
          'id': 'rc-dizimo',
          'code': 'DIZIMO',
          'name': 'Dízimo',
          'fundCode': 'DIZIMOS',
        },
        {
          'id': 'rc-alcada',
          'code': 'OFERTA_ALCADA',
          'name': 'Oferta alçada',
          'fundCode': 'OFERTAS_ALCADAS',
        },
        {
          'id': 'rc-culto',
          'code': 'OFERTA_CULTO',
          'name': 'Oferta de culto',
          'fundCode': 'OFERTAS_CULTO',
        },
      ],
      'finance/ledger': {
        'cycles': [_cycleOpen, _cycleClosed],
        'cycle': _cycleOpen,
        'items': [
          {
            'id': 'p1',
            'kind': 'PAYABLE',
            'date': '2099-12-31',
            'description': 'CAGECE SET/2026',
            'category': 'CAGECE',
            'amount': 50.73,
            'remaining': 50.73,
          },
          {
            'id': 'r1',
            'kind': 'REVENUE',
            'date': '2026-09-20',
            'description': 'Repasse bazar',
            'fundCode': 'OFERTAS_ALCADAS',
            'category': 'Bazar',
            'amount': 50,
          },
          {
            'id': 'r2',
            'kind': 'REVENUE',
            'date': '2026-09-15',
            'description': 'culto de doutrina',
            'fundCode': 'OFERTAS_CULTO',
            'category': 'Oferta de culto',
            'amount': 14.75,
          },
          {
            'id': 'r3',
            'kind': 'REVENUE',
            'date': '2026-09-15',
            'description': 'Ivan Gomes',
            'fundCode': 'DIZIMOS',
            'category': 'Dízimo',
            'amount': 200,
          },
          {
            'id': 'e1',
            'kind': 'EXPENSE',
            'date': '2026-09-20',
            'description': 'Microfone',
            'category': 'MATERIAL DE SOM',
            'paymentMethod': 'PIX',
            'amount': 972.69,
            'funds': {'OFERTAS_ALCADAS': 972.69},
          },
        ],
      },
      'me': {
        'fullName': 'Emanuel Costa',
        'email': 'emanuel@example.com',
        'memberships': [
          {'congregationName': 'ADTC Eixo do Carro', 'role': 'ADMIN'},
        ],
      },
    },
  );

  Future<void> pumpApp(WidgetTester tester, FakeApiClient client) async {
    await tester.pumpWidget(TesourariaApp(database: database, api: client));
    await tester.pumpAndSettle();
  }

  /// Abre a aba Tesouraria, toca em "Lançar" e escolhe Receita ou Despesa.
  Future<void> openNewEntry(WidgetTester tester, String kind) async {
    await tester.tap(find.text('Tesouraria'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lançar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(kind).last);
    await tester.pumpAndSettle();
  }

  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('dashboard mostra contas a vencer e saldos do ciclo atual', (
    tester,
  ) async {
    await pumpApp(tester, api());

    expect(find.text('ADTC Eixo do Carro'), findsOneWidget);
    expect(find.text('CAGECE SET/2026'), findsOneWidget);
    expect(find.text('Saldos do ciclo atual'), findsOneWidget);
    expect(find.text('R\$ 67,37'), findsOneWidget);
    expect(find.text('R\$ 19,39'), findsOneWidget);
    expect(find.text('R\$ 363,00'), findsWidgets);
  });

  testWidgets('relatório do ciclo segue a aba 1 da planilha', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(tester, api());
    await tester.tap(find.text('Ver relatório do ciclo'));
    await tester.pumpAndSettle();

    expect(find.text('14/09/2026 a 11/10/2026 (atual)'), findsOneWidget);
    expect(find.text('Fechar ciclo'), findsOneWidget);
    expect(find.text('Entradas'), findsOneWidget);
    expect(find.text('Total de ofertas de culto'), findsOneWidget);
    expect(find.text('R\$ 83,37'), findsOneWidget);
    expect(find.text('Bazar'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Saldos'), 200);
    expect(find.text('R\$ 67,37'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('R\$ 290,40'), 200);
    expect(find.text('R\$ 290,40'), findsOneWidget);
  });

  testWidgets('sem conexão e sem dados salvos mostra opção de tentar de novo', (
    tester,
  ) async {
    await pumpApp(tester, api(connected: false));

    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.textContaining('Offline'), findsOneWidget);
  });

  testWidgets('navega pelas abas até o perfil', (tester) async {
    await pumpApp(tester, api());

    await tester.tap(find.text('Tesouraria'));
    await tester.pumpAndSettle();
    expect(find.text('Lançar'), findsOneWidget);

    await tester.tap(find.text('Secretaria'));
    await tester.pumpAndSettle();
    expect(find.text('Aniversariantes'), findsOneWidget);

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Emanuel Costa'), findsOneWidget);
    expect(find.text('ADTC Eixo do Carro'), findsOneWidget);
    expect(find.text('Administrador'), findsOneWidget);
    expect(find.text('Sair'), findsOneWidget);
  });

  testWidgets('filtra membros pela busca', (tester) async {
    await pumpApp(tester, api());
    await tester.tap(find.text('Secretaria'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Membros'));
    await tester.pumpAndSettle();

    expect(find.text('Ana Souza'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'bruno');
    await tester.pump();
    expect(find.text('Ana Souza'), findsNothing);
    expect(find.text('Bruno Lima'), findsOneWidget);
  });

  testWidgets('cadastro offline entra na fila e aparece como pendente', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'required_fields_member': ['fullName'],
    });
    // Tela alta para o formulário inteiro caber sem rolagem.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = api(connected: false);
    await pumpApp(tester, client);
    client.connected = true;
    await tester.tap(find.text('Secretaria'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Membros'));
    await tester.pumpAndSettle();

    client.connected = false;
    await tester.tap(find.text('Novo membro'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Carla Dias');
    await tester.tap(find.text('Salvar membro'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('será enviado quando a conexão voltar'),
      findsOneWidget,
    );

    final pending = await database.pendingOperations(client.congregationId);
    expect(pending, hasLength(1));
    expect(pending.single.payload['path'], 'finance/members');
  });

  testWidgets('aniversariantes do mês destacam o aniversário de hoje', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BirthdaysPage(api: api(), today: DateTime(2026, 10, 4)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.text('Bruno Lima'), findsNothing);
    expect(find.textContaining('Hoje!'), findsOneWidget);
    expect(find.textContaining('Completa 36 anos'), findsOneWidget);
  });

  testWidgets('campos obrigatórios vazios ficam em vermelho ao salvar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(tester, api());
    await tester.tap(find.text('Secretaria'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Membros'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Novo membro'));
    await tester.pumpAndSettle();

    // Padrão: nome, nascimento e telefone obrigatórios, marcados com *.
    expect(find.text('Nome completo *'), findsOneWidget);
    expect(find.text('Telefone *'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Carla Dias');
    await tester.tap(find.text('Salvar membro'));
    await tester.pumpAndSettle();

    expect(find.text('Campo obrigatório.'), findsNWidgets(2));
    expect(
      find.text('Preencha os campos obrigatórios marcados em vermelho.'),
      findsOneWidget,
    );
  });

  testWidgets('despesa: combina fontes, mostra quanto falta e volta', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = api();
    await pumpApp(tester, client);
    await openNewEntry(tester, 'Despesa');

    await tester.enterText(find.byType(TextFormField).first, '300');
    await tester.pump();
    expect(
      find.text('Faltam R\$ 300,00 para completar R\$ 300,00'),
      findsOneWidget,
    );
    expect(find.text('Disponível: R\$ 67,37'), findsOneWidget);

    // Ofertas de culto cobrem só o saldo disponível; dízimos completam.
    final useRemaining = find.text('Usar o que falta');
    await tester.tap(useRemaining.at(0));
    await tester.pump();
    expect(
      find.text('Faltam R\$ 232,63 para completar R\$ 300,00'),
      findsOneWidget,
    );
    await tester.tap(useRemaining.at(2));
    await tester.pump();
    expect(find.text('Valor completo: R\$ 300,00'), findsOneWidget);

    // Seta de voltar retorna aos lançamentos.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Lançar despesa'), findsNothing);
    expect(find.text('Lançar'), findsOneWidget);
  });

  testWidgets('despesa: não salva se as fontes não fecham o valor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = api();
    await pumpApp(tester, client);
    await openNewEntry(tester, 'Despesa');

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '300');
    await tester.enterText(fields.at(1), 'Aluguel outubro');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ALUGUEL').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(3), '100');
    await tester.tap(find.text('Salvar despesa'));
    await tester.pumpAndSettle();

    expect(
      find.text('Faltam R\$ 200,00 para completar o valor da despesa.'),
      findsOneWidget,
    );
    expect(client.posts, isEmpty);
  });

  testWidgets('lançamentos: extrato com filtros, contas a pagar no topo', (
    tester,
  ) async {
    tallScreen(tester);
    await pumpApp(tester, api());
    await tester.tap(find.text('Tesouraria'));
    await tester.pumpAndSettle();

    expect(find.text('A PAGAR (1)'), findsOneWidget);
    expect(find.text('CAGECE SET/2026'), findsOneWidget);
    expect(find.text('Microfone'), findsOneWidget);

    // Movimento e tipo ficam escondidos atrás do botão de filtros.
    expect(find.widgetWithText(ChoiceChip, 'Bazar'), findsNothing);
    await tester.tap(find.byTooltip('Filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Entradas'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Bazar'));
    await tester.pumpAndSettle();
    expect(find.text('Microfone'), findsNothing);
    expect(find.text('CAGECE SET/2026'), findsNothing);
    expect(find.text('Repasse bazar'), findsOneWidget);
    expect(find.text('culto de doutrina'), findsNothing);

    // Chips dos filtros ativos permitem limpar.
    await tester.tap(find.byTooltip('Limpar tipo'));
    await tester.pumpAndSettle();
    expect(find.text('culto de doutrina'), findsOneWidget);
    expect(find.text('Microfone'), findsNothing);
    await tester.tap(find.byTooltip('Limpar movimento'));
    await tester.pumpAndSettle();
    expect(find.text('Microfone'), findsOneWidget);

    // Busca sem resultado no ciclo oferece buscar em todos os ciclos.
    expect(find.text('Buscar em todos os ciclos'), findsNothing);
    await tester.enterText(find.byType(TextField).first, 'inexistente');
    await tester.pumpAndSettle();
    expect(find.text('Nenhum lançamento encontrado.'), findsOneWidget);
    await tester.tap(find.text('Buscar em todos os ciclos'));
    await tester.pumpAndSettle();
    expect(find.text('Buscar em todos os ciclos'), findsNothing);
    expect(find.text('10/08/2026 a 04/10/2026'), findsOneWidget);
  });

  testWidgets('lançamentos: paga conta combinando fontes', (tester) async {
    tallScreen(tester);
    final client = api();
    await pumpApp(tester, client);
    await tester.tap(find.text('Tesouraria'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CAGECE SET/2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pagar'));
    await tester.pumpAndSettle();

    // Valor vem preenchido com o que está em aberto.
    expect(
      find.text('Faltam R\$ 50,73 para completar R\$ 50,73'),
      findsOneWidget,
    );
    await tester.tap(find.text('Usar o que falta').at(0));
    await tester.pump();
    await tester.tap(find.text('Registrar pagamento'));
    await tester.pumpAndSettle();

    final body = client.posts['finance/payables/p1/pay'] as Map;
    expect(body['amount'], 50.73);
    expect(body['fundingSources'], {'OFERTAS_CULTO': 50.73});
  });

  testWidgets('receita: oferta de culto com PIX e dinheiro', (tester) async {
    tallScreen(tester);
    final client = api();
    await pumpApp(tester, client);
    await openNewEntry(tester, 'Oferta de culto');

    await tester.tap(find.text('Culto de doutrina'));
    await tester.enterText(find.widgetWithText(TextField, 'PIX'), '10');
    await tester.enterText(find.widgetWithText(TextField, 'Dinheiro'), '4,75');
    await tester.pump();
    expect(find.text('R\$ 14,75'), findsOneWidget);
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    final body = client.posts['finance/revenues'] as Map;
    expect(body['fundCode'], 'OFERTAS_CULTO');
    expect(body['description'], 'Culto de doutrina');
    expect(body['pixAmount'], 10);
    expect(body['cashAmount'], 4.75);
    expect(body['categoryId'], 'rc-culto');
  });

  testWidgets('receita offline aparece no extrato aguardando sincronização', (
    tester,
  ) async {
    tallScreen(tester);
    final client = api();
    await pumpApp(tester, client);
    await openNewEntry(tester, 'Dízimo');
    client.connected = false;

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome de quem contribuiu *'),
      'Maria Lima',
    );
    await tester.enterText(find.widgetWithText(TextField, 'PIX'), '100');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    // Volta à lista sem conexão: mostra o cache e o lançamento pendente.
    expect(find.text('Maria Lima'), findsOneWidget);
    expect(find.textContaining('Aguardando sincronização'), findsWidgets);
  });
}
