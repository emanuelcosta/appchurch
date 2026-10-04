import 'package:flutter/material.dart';

import '../dashboard_models.dart';

/// Seleção do ciclo de prestação de contas exibido no dashboard.
class CycleSelector extends StatelessWidget {
  const CycleSelector({
    super.key,
    required this.cycles,
    required this.selectedId,
    required this.onChanged,
  });

  final List<CycleInfo> cycles;
  final String? selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: ValueKey(selectedId),
      initialValue: selectedId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Ciclo de prestação de contas',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.date_range),
      ),
      items: [
        for (final cycle in cycles)
          DropdownMenuItem(value: cycle.id, child: Text(cycle.label)),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}
