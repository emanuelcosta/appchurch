import 'package:appchurch/core/local/app_database.dart';
import 'package:appchurch/main.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_api_client.dart';

const _open = {
  'id': 'c-open',
  'startDate': '2026-09-14',
  'endDate': '2026-10-11',
  'status': 'OPEN',
};
const _closed = {
  'id': 'c-closed',
  'startDate': '2026-08-10',
  'endDate': '2026-09-13',
  'status': 'CLOSED',
};

Map<String, Object?> _responses() => {
  'finance/dashboard': {
    'cycles': [_open],
    'cycle': _open,
  },
  'me': {'fullName': 'Tesoureiro', 'memberships': []},
  'finance/accountability-cycles': [_open, _closed],
  'finance/revenue-categories': [
    {
      'id': 'rc-culto',
      'code': 'OFERTA_CULTO',
      'name': 'Oferta de culto',
      'fundCode': 'OFERTAS_CULTO',
    },
  ],
  'finance/expense-categories': [
    {'id': 'cat-aluguel', 'name': 'ALUGUEL'},
  ],
  'finance/ledger': {
    'cycles': [_open, _closed],
    'cycle': _open,
    'items': [
      {
        'id': 'r1',
        'kind': 'REVENUE',
        'date': '2026-09-15',
        'description': 'Culto de doutrina',
        'fundCode': 'OFERTAS_CULTO',
        'categoryId': 'rc-culto',
        'category': 'Oferta de culto',
        'amount': 14.75,
        'pixAmount': 10,
        'cashAmount': 4.75,
      },
      {
        'id': 'r-old',
        'kind': 'REVENUE',
        'date': '2026-08-20',
        'description': 'Culto antigo',
        'fundCode': 'OFERTAS_CULTO',
        'category': 'Oferta de culto',
        'amount': 30,
        'cashAmount': 30,
      },
      {
        'id': 'p1',
        'kind': 'PAYABLE',
        'date': '2099-12-31',
        'description': 'CAGECE OUT/2026',
        'category': 'CAGECE',
        'amount': 50,
        'remaining': 50,
      },
      {
        'id': 'pay-1',
        'kind': 'EXPENSE',
        'payableId': 'payable-1',
        'paidOnCreation': true,
        'date': '2026-09-20',
        'description': 'Aluguel setembro',
        'categoryId': 'cat-aluguel',
        'category': 'ALUGUEL',
        'paymentMethod': 'PIX',
        'amount': 350,
        'funds': {'DIZIMOS': 350},
      },
    ],
  },
};

void main() {
  late AppDatabase database;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() => database.close());

  Future<FakeApiClient> openLedger(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = FakeApiClient(database: database, responses: _responses());
    await tester.pumpWidget(TesourariaApp(database: database, api: client));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tesouraria'));
    await tester.pumpAndSettle();
    return client;
  }

  Future<void> openItem(WidgetTester tester, String description) async {
    await tester.tap(find.text(description));
    await tester.pumpAndSettle();
  }

  testWidgets('edita receita mantendo o mesmo id', (tester) async {
    final client = await openLedger(tester);
    await openItem(tester, 'Culto de doutrina');

    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(find.text('Editar receita'), findsOneWidget);
    // Formulário vem preenchido com os valores lançados.
    expect(find.text('R\$ 14,75'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Dinheiro'), '9,75');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    final body = client.posts['finance/revenues'] as Map;
    expect(body['id'], 'r1');
    expect(body['pixAmount'], 10);
    expect(body['cashAmount'], 9.75);
    expect(body['categoryId'], 'rc-culto');
  });

  testWidgets('estorno de receita exige motivo e envia para a API', (
    tester,
  ) async {
    final client = await openLedger(tester);
    await openItem(tester, 'Culto de doutrina');

    await tester.tap(find.text('Estornar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar estorno'));
    await tester.pumpAndSettle();
    expect(find.text('Informe o motivo.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Valor duplicado');
    await tester.tap(find.text('Confirmar estorno'));
    await tester.pumpAndSettle();

    final body = client.posts['finance/revenues/r1/reverse'] as Map;
    expect(body['reason'], 'Valor duplicado');
  });

  testWidgets('estorno de despesa pergunta se cancela ou mantém a conta', (
    tester,
  ) async {
    final client = await openLedger(tester);
    await openItem(tester, 'Aluguel setembro');

    await tester.tap(find.text('Estornar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Pago em duplicidade');
    await tester.tap(find.text('Manter a conta em aberto'));
    await tester.tap(find.text('Confirmar estorno'));
    await tester.pumpAndSettle();

    final body = client.posts['finance/payments/pay-1/reverse'] as Map;
    expect(body['cancelExpense'], false);
  });

  testWidgets('lançamento de ciclo fechado não pode ser alterado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = FakeApiClient(database: database, responses: _responses());
    await tester.pumpWidget(TesourariaApp(database: database, api: client));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tesouraria'));
    await tester.pumpAndSettle();
    await openItem(tester, 'Culto antigo');

    expect(
      find.text('Lançamento de ciclo fechado: não pode ser alterado.'),
      findsOneWidget,
    );
    expect(find.text('Editar'), findsNothing);
    expect(find.text('Estornar'), findsNothing);
  });

  testWidgets('envio recusado aparece em vermelho e pode ser descartado', (
    tester,
  ) async {
    final client = await openLedger(tester);
    client.rejections['finance/revenues'] =
        'A data 20/08/2026 pertence a um ciclo já fechado.';

    // Lança offline para ir à fila; ao reconectar, a API recusa.
    client.connected = false;
    await tester.tap(find.text('Lançar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oferta de culto').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Culto de doutrina'));
    await tester.enterText(find.widgetWithText(TextField, 'PIX'), '5');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    client.connected = true;
    // Voltar a falar com a API (abrir o Início) dispara a sincronização.
    await tester.tap(find.text('Início'));
    await tester.pumpAndSettle();

    expect(find.textContaining('recusado(s)'), findsOneWidget);
    await tester.tap(find.textContaining('recusado(s)'));
    await tester.pumpAndSettle();
    expect(find.text('Envios recusados'), findsOneWidget);
    expect(
      find.text('A data 20/08/2026 pertence a um ciclo já fechado.'),
      findsOneWidget,
    );
    expect(find.text('Corrigir'), findsOneWidget);

    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar').last);
    await tester.pumpAndSettle();
    expect(find.text('Nenhum envio recusado.'), findsOneWidget);
  });

  testWidgets('pagamento offline aparece no extrato e pode ser desfeito', (
    tester,
  ) async {
    final client = await openLedger(tester);
    client.connected = false;

    await openItem(tester, 'CAGECE OUT/2026');
    await tester.tap(find.text('Pagar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '20');
    await tester.pump();
    await tester.tap(find.text('Usar o que falta').at(0));
    await tester.pump();
    await tester.tap(find.text('Registrar pagamento'));
    await tester.pumpAndSettle();

    // Extrato (do cache) já mostra o efeito do pagamento feito offline.
    expect(
      find.textContaining('Sem 1 lançamento(s) aguardando'),
      findsOneWidget,
    );
    expect(find.text('-R\$ 20,00'), findsOneWidget);
    expect(find.text('R\$ 30,00'), findsOneWidget);

    // O pagamento pendente pode ser desfeito antes de enviar.
    await tester.tap(find.text('-R\$ 20,00'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desfazer (não enviar)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desfazer').last);
    await tester.pumpAndSettle();

    expect(find.text('-R\$ 20,00'), findsNothing);
    expect(find.text('R\$ 50,00'), findsOneWidget);
    expect(await client.pendingWrites(), 0);
  });
}
