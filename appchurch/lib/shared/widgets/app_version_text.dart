import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Versão do app (pubspec.yaml), exibida no rodapé do login e no perfil.
class AppVersionText extends StatelessWidget {
  const AppVersionText({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            info == null ? '' : 'Versão ${info.version} (${info.buildNumber})',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );
      },
    );
  }
}
