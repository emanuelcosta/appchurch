import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';

/// Uma fonte de dinheiro (fundo) no rateio da despesa: mostra o saldo
/// disponível, recebe o valor e oferece "Usar o que falta".
class FundingSourceCard extends StatelessWidget {
  const FundingSourceCard({
    super.key,
    required this.name,
    required this.icon,
    required this.available,
    required this.controller,
    required this.onChanged,
    required this.onUseRemaining,
    this.canUseRemaining = true,
  });

  final String name;
  final IconData icon;

  /// Saldo da fonte no ciclo atual; `null` quando não foi possível carregar.
  final double? available;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final VoidCallback onUseRemaining;
  final bool canUseRemaining;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final value = parseMoney(controller.text) ?? 0;
    final overBalance = available != null && value > available! + 0.005;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  available == null
                      ? 'Saldo indisponível'
                      : 'Disponível: ${formatMoney(available!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => onChanged(),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixText: 'R\$ ',
                      hintText: '0,00',
                      border: const OutlineInputBorder(),
                      errorText: overBalance
                          ? 'Acima do saldo disponível'
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: canUseRemaining ? onUseRemaining : null,
                  child: const Text('Usar o que falta'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
