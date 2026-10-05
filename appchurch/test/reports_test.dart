import 'dart:io';

import 'package:appchurch/core/local/app_database.dart';
import 'package:appchurch/features/export/export_service.dart';
import 'package:appchurch/features/ledger/ledger_page.dart';
import 'package:appchurch/features/reports/reports_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_api_client.dart';

/// Registra os pedidos de exportação em vez de gerar e compartilhar.
class RecordingExporter extends ExportService {
  RecordingExporter(super.api);

  final statements = <({String? cycleId, DateTimeRange? period})>[];
  int members = 0;

  @override
  Future<File> exportStatement({String? cycleId, DateTimeRange? period}) async {
    statements.add((cycleId: cycleId, period: period));
    return File('extrato.xlsx');
  }

  @override
  Future<File> exportMembers() async {
    members++;
    return File('membros.xlsx');
  }
}

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

void main() {
  late AppDatabase database;
  late FakeApiClient api;
  late RecordingExporter exporter;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    api = FakeApiClient(
      database: database,
      responses: {
        'finance/dashboard': {
          'cycles': [_open, _closed],
          'cycle': _open,
        },
        'finance/ledger': {
          'cycles': [_open, _closed],
          'cycle': _open,
          'items': [],
        },
      },
    );
    exporter = RecordingExporter(api);
  });
  tearDown(() => database.close());

  Future<void> pumpReports(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ReportsPage(api: api, exporter: exporter),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('relatórios: exporta o extrato do ciclo atual', (tester) async {
    await pumpReports(tester);
    expect(find.text('14/09/2026 a 11/10/2026 (atual)'), findsOneWidget);

    await tester.tap(find.text('Gerar Excel do extrato'));
    await tester.pumpAndSettle();
    expect(exporter.statements.single.cycleId, isNull);
    expect(exporter.statements.single.period, isNull);
  });

  testWidgets('relatórios: por período exige escolher as datas', (
    tester,
  ) async {
    await pumpReports(tester);
    await tester.tap(find.text('Período'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gerar Excel do extrato'));
    await tester.pumpAndSettle();

    expect(find.text('Escolha o período do extrato.'), findsOneWidget);
    expect(exporter.statements, isEmpty);
  });

  testWidgets('relatórios: membros pede confirmação (dados pessoais)', (
    tester,
  ) async {
    await pumpReports(tester);
    await tester.tap(find.text('Gerar Excel dos membros'));
    await tester.pumpAndSettle();
    expect(find.textContaining('dados pessoais'), findsWidgets);

    await tester.tap(find.text('Exportar'));
    await tester.pumpAndSettle();
    expect(exporter.members, 1);
  });

  testWidgets('tesouraria: botão exporta o ciclo exibido', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: LedgerPage(api: api, onOpenReport: () {}, exporter: exporter),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Exportar para Excel'));
    await tester.pumpAndSettle();
    expect(exporter.statements.single.cycleId, 'c-open');
  });
}
