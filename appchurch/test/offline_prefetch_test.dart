import 'package:appchurch/core/local/app_database.dart';
import 'package:appchurch/features/home/offline_prefetch.dart';
import 'package:appchurch/features/members/members_service.dart';
import 'package:appchurch/features/revenues/revenues_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_api_client.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  FakeApiClient api() => FakeApiClient(
    database: database,
    responses: {
      'finance/dashboard': {
        'cycles': [
          {'id': 'c1', 'startDate': '2026-09-14', 'status': 'OPEN'},
        ],
        'cycle': {'id': 'c1', 'startDate': '2026-09-14', 'status': 'OPEN'},
      },
      'finance/ledger': {'cycles': [], 'items': []},
      'finance/accountability-cycles': [],
      'finance/revenue-categories': [
        {'id': 'rc1', 'name': 'Bazar', 'fundCode': 'OFERTAS_ALCADAS'},
      ],
      'finance/expense-categories': [],
      'finance/members': [
        {'id': 'm1', 'full_name': 'Ana Souza'},
      ],
      'me': {'fullName': 'Tesoureiro'},
    },
  );

  test('com conexão, baixa os dados das telas para usar offline', () async {
    final client = api();
    await OfflinePrefetch(client).run();

    // Telas nunca abertas funcionam offline com o que foi baixado.
    client.connected = false;
    final members = await MembersService(client).list();
    final types = await RevenuesService(client).categories();
    expect(members.single.fullName, 'Ana Souza');
    expect(types.single.name, 'Bazar');
  });

  test('não baixa de novo antes do intervalo', () async {
    var now = DateTime(2026, 10, 4, 9);
    final client = api();
    final prefetch = OfflinePrefetch(client, clock: () => now);
    await prefetch.run();

    client.connected = false;
    // Dentro do intervalo: nem tenta (não gera erro nem chamada).
    now = now.add(const Duration(minutes: 5));
    await prefetch.run();
    expect(client.offline.value, isFalse);
  });
}
