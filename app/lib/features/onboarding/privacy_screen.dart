import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/nav.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Три честных пункта о приватности (раздел 1.12): что не храним,
/// что остаётся на телефоне и что оператор всё равно видит.
class PrivacyPoints extends StatelessWidget {
  const PrivacyPoints({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final points = [
      (Icons.check_rounded, OtColors.success, l.privacyNoHistory),
      (Icons.check_rounded, OtColors.success, l.privacyKeyStays),
      (Icons.info_outline_rounded, OtColors.warning, l.privacyOperatorSees),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (icon, color, text) in points) ...[
          GlassCard(
            radius: 18,
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 12),
                Expanded(child: Text(text, style: OtType.bodyStrong)),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// Приватность из настроек — только чтение.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return OtScaffold(
      title: l.settingsPrivacy,
      onBack: () => goBack(context, Routes.settings),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Text(l.privacyTitle, style: OtType.display(24)),
          const SizedBox(height: 20),
          const PrivacyPoints(),
        ],
      ),
    );
  }
}
