import 'package:flutter/material.dart';

/// Faixa exibida quando o app está sem acesso à API, tem envios pendentes ou
/// envios recusados (estes em vermelho e tocáveis, para corrigir).
class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({
    super.key,
    required this.offline,
    required this.pending,
    this.rejected = 0,
    this.onTapRejected,
  });

  final bool offline;
  final int pending;
  final int rejected;
  final VoidCallback? onTapRejected;

  @override
  Widget build(BuildContext context) {
    if (!offline && pending == 0 && rejected == 0) {
      return const SizedBox.shrink();
    }
    final colors = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.bodySmall;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (rejected > 0)
          Material(
            color: colors.error,
            child: InkWell(
              onTap: onTapRejected,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 18, color: colors.onError),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$rejected envio(s) recusado(s) — toque para corrigir',
                        style: textStyle?.copyWith(
                          color: colors.onError,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: colors.onError),
                  ],
                ),
              ),
            ),
          ),
        if (offline || pending > 0)
          Material(
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
                      [
                        if (offline)
                          'Offline: exibindo os últimos dados salvos',
                        if (pending > 0)
                          '$pending envio(s) aguardando sincronização',
                      ].join(' • '),
                      style: textStyle,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
