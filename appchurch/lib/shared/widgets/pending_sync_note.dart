import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';

/// Aviso de que totais e saldos exibidos já incluem lançamentos feitos
/// offline, ainda não confirmados pela API (valores provisórios).
class PendingSyncNote extends StatelessWidget {
  const PendingSyncNote({super.key, required this.api, this.compact = false});

  final ApiClient api;

  /// Versão em uma linha, para usar dentro de outros cartões.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: api.pendingWrites(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count == 0) return const SizedBox.shrink();
        final colors = Theme.of(context).colorScheme;
        final text =
            'Inclui $count lançamento(s) ainda não sincronizado(s): valores '
            'provisórios. Os repasses são recalculados quando a conexão com '
            'a API voltar.';
        if (compact) {
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: colors.secondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Inclui $count lançamento(s) ainda não sincronizado(s) '
                    '(provisório).',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          );
        }
        return Card(
          color: colors.secondaryContainer,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.cloud_upload_outlined),
            title: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        );
      },
    );
  }
}
