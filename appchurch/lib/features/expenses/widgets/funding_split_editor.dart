import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../dashboard/dashboard_models.dart';
import '../expense_models.dart';
import 'funding_progress.dart';
import 'funding_source_card.dart';

const _fundIcons = {
  'OFERTAS_CULTO': Icons.church,
  'OFERTAS_ALCADAS': Icons.account_balance,
  'DIZIMOS': Icons.volunteer_activism,
};

/// Controla os valores digitados para cada fonte de dinheiro.
class FundingSplitController {
  final controllers = {
    for (final fund in fundNames.keys) fund: TextEditingController(),
  };

  FundingSplit split(double total) => FundingSplit(
    total: total,
    sources: {
      for (final entry in controllers.entries)
        entry.key: parseMoney(entry.value.text) ?? 0,
    },
  );

  /// Preenche os valores (edição de uma despesa já lançada).
  void fill(Map<String, double> sources) {
    for (final entry in sources.entries) {
      final controller = controllers[entry.key];
      if (controller != null && entry.value > 0) {
        controller.text = formatMoneyInput(entry.value);
      }
    }
  }

  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
  }
}

/// Rateio de um pagamento entre as fontes (como na planilha): barra de
/// quanto falta e um cartão por fonte com saldo e "Usar o que falta".
class FundingSplitEditor extends StatelessWidget {
  const FundingSplitEditor({
    super.key,
    required this.total,
    required this.controller,
    required this.available,
    required this.onChanged,
    this.availableNote,
  });

  final double total;
  final FundingSplitController controller;

  /// Saldo de cada fonte no ciclo atual; `null` se não foi possível carregar.
  final Map<String, double>? available;
  final VoidCallback onChanged;

  /// Aviso sobre o saldo disponível (ex.: lançamentos ainda não sincronizados).
  final Widget? availableNote;

  void _useRemaining(String fund) {
    final value = controller
        .split(total)
        .suggestionFor(fund, available?[fund] ?? 0);
    controller.controllers[fund]!.text = value > 0
        ? formatMoneyInput(value)
        : '';
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'De onde sai o dinheiro',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        FundingProgress(split: controller.split(total)),
        ?availableNote,
        const SizedBox(height: 8),
        for (final fund in fundNames.keys)
          FundingSourceCard(
            name: fundNames[fund]!,
            icon: _fundIcons[fund]!,
            available: available?[fund],
            controller: controller.controllers[fund]!,
            onChanged: onChanged,
            onUseRemaining: () => _useRemaining(fund),
            canUseRemaining: total > 0,
          ),
      ],
    );
  }
}
