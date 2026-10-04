import 'package:appchurch/core/settings/due_alert_settings.dart';
import 'package:appchurch/features/dashboard/dashboard_models.dart';
import 'package:appchurch/features/dashboard/widgets/pending_payables_card.dart';
import 'package:appchurch/shared/widgets/pulsing_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 10, 4);
  const settings = DueAlertSettings(warningDays: 10, urgentDays: 3);

  test('classifica o alerta pelos dias que faltam', () {
    expect(
      settings.levelFor(DateTime(2026, 10, 1), today),
      DueAlertLevel.urgent,
    );
    expect(
      settings.levelFor(DateTime(2026, 10, 7), today),
      DueAlertLevel.urgent,
    );
    expect(
      settings.levelFor(DateTime(2026, 10, 8), today),
      DueAlertLevel.warning,
    );
    expect(
      settings.levelFor(DateTime(2026, 10, 14), today),
      DueAlertLevel.warning,
    );
    expect(
      settings.levelFor(DateTime(2026, 10, 15), today),
      DueAlertLevel.none,
    );
  });

  Future<Color?> borderColorFor(WidgetTester tester, DateTime dueDate) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PendingPayablesCard(
            payables: [
              PendingPayable(
                description: 'Aluguel',
                dueDate: dueDate,
                remaining: 350,
                overdue: dueDate.isBefore(today),
              ),
            ],
            settings: settings,
            today: today,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return tester.widget<PulsingBorder>(find.byType(PulsingBorder)).color;
  }

  testWidgets('borda vermelha perto do vencimento', (tester) async {
    expect(await borderColorFor(tester, DateTime(2026, 10, 5)), isNot(null));
    expect(find.text('Vence amanhã · 05/10/2026'), findsOneWidget);
    final theme = Theme.of(tester.element(find.byType(PendingPayablesCard)));
    expect(
      tester.widget<PulsingBorder>(find.byType(PulsingBorder)).color,
      theme.colorScheme.error,
    );
  });

  testWidgets('borda laranja no prazo de aviso', (tester) async {
    expect(
      await borderColorFor(tester, DateTime(2026, 10, 10)),
      const Color(0xFFF57C00),
    );
  });

  testWidgets('sem borda quando o vencimento está longe', (tester) async {
    expect(await borderColorFor(tester, DateTime(2026, 10, 30)), isNull);
  });
}
