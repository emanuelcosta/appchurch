import 'package:flutter/material.dart';

/// Faixa exibida quando o app está sem acesso à API ou tem envios pendentes.
class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({
    super.key,
    required this.offline,
    required this.pending,
  });

  final bool offline;
  final int pending;

  @override
  Widget build(BuildContext context) {
    if (!offline && pending == 0) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final message = [
      if (offline) 'Offline: exibindo os últimos dados salvos',
      if (pending > 0) '$pending envio(s) aguardando sincronização',
    ].join(' • ');
    return Material(
      color: offline ? colors.errorContainer : colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(
              offline ? Icons.cloud_off : Icons.cloud_upload_outlined,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
