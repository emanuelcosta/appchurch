import 'package:appchurch/core/local/app_database.dart';
import 'package:appchurch/features/members/members_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_api_client.dart';

const _members = [
  {
    'id': 'm1',
    'full_name': 'Ana Souza',
    'phone': '85 99999-0000',
    // Valor da planilha fora da lista do formulário ("Casado(a)").
    'marital_status': 'Casado',
    'ministry_role': 'MEMBRO',
  },
];

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  Future<FakeApiClient> openMembers(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = FakeApiClient(
      database: database,
      responses: {'finance/members': _members},
    );
    await tester.pumpWidget(MaterialApp(home: MembersPage(api: client)));
    await tester.pumpAndSettle();
    return client;
  }

  Future<void> editAna(WidgetTester tester) async {
    await tester.tap(find.text('Ana Souza'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
  }

  testWidgets('edita a ficha mantendo o mesmo id e os dados existentes', (
    tester,
  ) async {
    final client = await openMembers(tester);
    await editAna(tester);

    expect(find.text('Editar membro'), findsOneWidget);
    expect(find.text('Casado'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, '85 99999-0000'),
      '85 98888-1111',
    );
    await tester.tap(find.text('Salvar membro'));
    await tester.pumpAndSettle();

    final body = client.posts['finance/members'] as Map;
    expect(body['id'], 'm1');
    expect(body['fullName'], 'Ana Souza');
    expect(body['phone'], '85 98888-1111');
    expect(body['maritalStatus'], 'Casado');
    expect(body['ministryRole'], 'MEMBRO');
  });

  testWidgets('edição offline aparece na lista como pendente', (tester) async {
    final client = await openMembers(tester);
    client.connected = false;
    await editAna(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, '85 99999-0000'),
      '85 97777-2222',
    );
    await tester.tap(find.text('Salvar membro'));
    await tester.pumpAndSettle();

    expect(find.textContaining('85 97777-2222'), findsOneWidget);
    expect(find.textContaining('Aguardando sincronização'), findsOneWidget);
    // Continua um membro só (a edição substitui, não duplica).
    expect(find.text('Ana Souza'), findsOneWidget);
  });
}
