import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';

/// Aviso de que totais e saldos exibidos ainda não incluem os lançamentos
/// feitos offline (eles são calculados pela API depois da sincronização).
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
            'Valores sem $count lançamento(s) aguardando sincronização. '
            'Eles entram nos totais quando a conexão com a API voltar.';
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
                    'Sem $count lançamento(s) aguardando sincronização.',
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
