import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Домашний экран: два режима, которые нельзя перепутать (US-OT07).
class ModeScreen extends StatelessWidget {
  const ModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return OtScaffold(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const TunnelLogo(size: 34),
          const SizedBox(width: 10),
          Text(l.appName, style: OtType.wordmark()),
        ],
      ),
      trailing: GlassIconButton(
        icon: Icons.settings_outlined,
        tooltip: l.commonSettings,
        onPressed: () => context.push(Routes.settings),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Text(l.modeTitle, style: OtType.display(30)),
          const SizedBox(height: 10),
          Text(l.modeSubtitle, style: OtType.body),
          const SizedBox(height: 28),
          _ModeCard(
            key: const Key('mode-managed'),
            title: l.modeManagedTitle,
            body: l.modeManagedBody,
            tag: OtTag(l.modeManagedTag),
            icon: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [OtColors.accent, OtColors.navy],
                ),
                boxShadow: [
                  BoxShadow(
                    color: OtColors.accent.withValues(alpha: 0.55),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: const Center(child: TunnelLogo(size: 30)),
            ),
            strong: true,
            onTap: () => context.push(Routes.managed),
          ),
          const SizedBox(height: 16),
          _ModeCard(
            key: const Key('mode-byo'),
            title: l.modeByoTitle,
            body: l.modeByoBody,
            tag: OtTag(l.modeByoTag, color: OtColors.cyan),
            icon: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: OtColors.glassStrong,
                border: Border.all(color: OtColors.glassBorder),
              ),
              child: const Icon(Icons.vpn_key_outlined,
                  color: Color(0xFFC3D0FF), size: 24),
            ),
            onTap: () => context.push(Routes.byo),
          ),
        ],
      ),
      actions: [
        GlassCard(
          radius: 18,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.shield_outlined,
                  size: 18, color: OtColors.accentLight),
              const SizedBox(width: 10),
              Expanded(child: Text(l.modePrivacyNote, style: OtType.bodySmall)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    super.key,
    required this.title,
    required this.body,
    required this.tag,
    required this.icon,
    required this.onTap,
    this.strong = false,
  });

  final String title;
  final String body;
  final Widget tag;
  final Widget icon;
  final VoidCallback onTap;
  final bool strong;

  @override
  Widget build(BuildContext context) => GlassCard(
        onTap: onTap,
        radius: 26,
        strong: strong,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox.square(dimension: 52, child: icon),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: OtType.title),
                  const SizedBox(height: 6),
                  Text(body, style: OtType.body.copyWith(fontSize: 14)),
                  const SizedBox(height: 10),
                  tag,
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 14, left: 6),
              child: Icon(Icons.chevron_right_rounded,
                  color: OtColors.accentLight),
            ),
          ],
        ),
      );
}
