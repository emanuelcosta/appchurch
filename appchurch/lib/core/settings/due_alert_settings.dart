import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Nível de alerta de uma conta conforme os dias que faltam para vencer.
enum DueAlertLevel { none, warning, urgent }

/// Prazos (em dias) para destacar contas a vencer no dashboard.
class DueAlertSettings {
  const DueAlertSettings({this.warningDays = 10, this.urgentDays = 3});

  /// Até quantos dias antes do vencimento a conta fica laranja.
  final int warningDays;

  /// Até quantos dias antes do vencimento (ou vencida) a conta fica vermelha.
  final int urgentDays;

  DueAlertLevel levelFor(DateTime? dueDate, DateTime today) {
    if (dueDate == null) return DueAlertLevel.none;
    final daysLeft = _dateOnly(dueDate).difference(_dateOnly(today)).inDays;
    if (daysLeft <= urgentDays) return DueAlertLevel.urgent;
    if (daysLeft <= warningDays) return DueAlertLevel.warning;
    return DueAlertLevel.none;
  }
}

/// Guarda os prazos de alerta neste aparelho.
class DueAlertSettingsStore {
  static const _warningKey = 'due_alert_warning_days';
  static const _urgentKey = 'due_alert_urgent_days';

  final ValueNotifier<DueAlertSettings> settings = ValueNotifier(
    const DueAlertSettings(),
  );

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      settings.value = DueAlertSettings(
        warningDays: prefs.getInt(_warningKey) ?? 10,
        urgentDays: prefs.getInt(_urgentKey) ?? 3,
      );
    } catch (_) {
      // Sem armazenamento disponível: mantém os prazos padrão.
    }
  }

  Future<void> save(DueAlertSettings value) async {
    settings.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_warningKey, value.warningDays);
    await prefs.setInt(_urgentKey, value.urgentDays);
  }
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
