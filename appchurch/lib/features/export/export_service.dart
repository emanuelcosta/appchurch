import 'dart:io';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api/api_client.dart';
import '../../core/utils/formatters.dart';
import '../dashboard/dashboard_service.dart';
import '../ledger/ledger_service.dart';
import '../members/members_service.dart';
import '../profile/profile_service.dart';
import 'members_workbook.dart';
import 'statement_workbook.dart';

const _xlsxMime =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// Gera as planilhas Excel (extrato e membros) com os dados da API — ou da
/// cópia do aparelho, offline — e abre o compartilhamento do Android
/// (WhatsApp, e-mail, Drive, salvar em arquivos...).
class ExportService {
  ExportService(this._api, {this.share});

  final ApiClient _api;

  /// Substitui o compartilhamento (testes).
  final Future<void> Function(File file, String subject)? share;

  /// Extrato de um ciclo ([cycleId]; sem ele, o ciclo atual) ou de um
  /// [period] escolhido. Retorna o arquivo gerado.
  Future<File> exportStatement({String? cycleId, DateTimeRange? period}) async {
    final congregation = await _congregationName();
    final ledger = LedgerService(_api);
    final List<int> bytes;
    final String label;
    if (period != null) {
      final data = await ledger.load(period: period);
      label = '${formatDate(period.start)} a ${formatDate(period.end)}';
      bytes = buildStatementWorkbook(
        items: data.items,
        periodLabel: label,
        congregationName: congregation,
      );
    } else {
      final report = await DashboardService(_api).load(cycleId: cycleId);
      final data = await ledger.load(cycleId: report.cycle?.id ?? cycleId);
      label = cyclePeriodLabel(report.cycle);
      bytes = buildStatementWorkbook(
        items: data.items,
        report: report,
        periodLabel: label,
        congregationName: congregation,
      );
    }
    final start = period?.start;
    final fileName = start == null
        ? 'extrato-ciclo-${_stamp(DateTime.now())}.xlsx'
        : 'extrato-${toIsoDate(start)}-a-${toIsoDate(period!.end)}.xlsx';
    return _saveAndShare(bytes, fileName, 'Extrato da tesouraria — $label');
  }

  /// Ficha completa dos membros (contém dados pessoais).
  Future<File> exportMembers() async {
    final members = await MembersService(_api).list();
    final bytes = buildMembersWorkbook(
      members,
      congregationName: await _congregationName(),
    );
    return _saveAndShare(
      bytes,
      'membros-${_stamp(DateTime.now())}.xlsx',
      'Membros da congregação',
    );
  }

  Future<File> _saveAndShare(
    List<int> bytes,
    String fileName,
    String subject,
  ) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    if (share != null) {
      await share!(file, subject);
    } else {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: _xlsxMime, name: fileName)],
          subject: subject,
          title: subject,
        ),
      );
    }
    return file;
  }

  Future<String?> _congregationName() async {
    try {
      return (await ProfileService(_api).load()).congregationName;
    } catch (_) {
      return null;
    }
  }

  static String _stamp(DateTime date) =>
      '${toIsoDate(date)}-${date.hour.toString().padLeft(2, '0')}'
      '${date.minute.toString().padLeft(2, '0')}';
}
