import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/settings.dart';
import '../../core/config.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/failure_view.dart';
import '../../ui/nav.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../onboarding/privacy_screen.dart';
import 'managed_controller.dart';
import 'managed_widgets.dart';

/// Вход в управляемый режим. Без согласия — сценарий A:
/// текст о приватности, затем согласие, затем регистрация.
class ManagedScreen extends ConsumerWidget {
  const ManagedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consent = ref.watch(settingsProvider.select((s) => s.consentVersion));
    if (consent != kConsentVersion) return const _ManagedOnboarding();
    return const _ManagedMain();
  }
}

class _ManagedOnboarding extends ConsumerStatefulWidget {
  const _ManagedOnboarding();

  @override
  ConsumerState<_ManagedOnboarding> createState() => _ManagedOnboardingState();
}

class _ManagedOnboardingState extends ConsumerState<_ManagedOnboarding> {
  int _step = 0;
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_step == 0) {
      return OtScaffold(
        title: l.managedTitle,
        onBack: () => goBack(context, Routes.home),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Text(l.privacyTitle, style: OtType.display(24)),
            const SizedBox(height: 20),
            const PrivacyPoints(),
          ],
        ),
        actions: [
          PrimaryButton(
            label: l.privacyAccept,
            onPressed: () => setState(() => _step = 1),
          ),
        ],
      );
    }
    return OtScaffold(
      title: l.managedTitle,
      onBack: () => setState(() => _step = 0),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Text(l.consentTitle, style: OtType.display(24)),
          const SizedBox(height: 14),
          Text(l.consentBody, style: OtType.body),
          const SizedBox(height: 20),
          GlassCard(
            radius: 18,
            padding: EdgeInsets.zero,
            onTap: () => setState(() => _agreed = !_agreed),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Checkbox(
                    key: const Key('consent-checkbox'),
                    value: _agreed,
                    onChanged: (v) => setState(() => _agreed = v ?? false),
                    activeColor: OtColors.accentBright,
                    side: const BorderSide(color: OtColors.muted, width: 1.5),
                  ),
                  Expanded(
                    child: Text(l.consentCheckbox, style: OtType.bodyStrong),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        PrimaryButton(
          label: l.commonContinue,
          onPressed: _agreed
              ? () => ref
                  .read(settingsProvider.notifier)
                  .acceptConsent(kConsentVersion)
              : null,
        ),
        GhostButton(label: l.commonBack, onPressed: () => setState(() => _step = 0)),
      ],
    );
  }
}

class _ManagedMain extends ConsumerWidget {
  const _ManagedMain();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(managedControllerProvider);
    final c = ref.read(managedControllerProvider.notifier);

    Widget body;
    var actions = <Widget>[];

    switch (s.phase) {
      case ManagedPhase.loading:
        body = WaitingView(title: l.commonLoading);
      case ManagedPhase.registering:
        body = WaitingView(title: l.managedRegistering);
      case ManagedPhase.idle:
        body = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AccessOrb(
              label: l.managedGetAccess,
              onTap: s.nodesAvailable && !s.busy ? c.requestAccess : null,
            ),
            const SizedBox(height: 16),
            StatusPill(label: l.managedIdleStatus, kind: PillKind.idle),
            const SizedBox(height: 16),
            Text(
              s.nodesAvailable ? l.managedIdleHint : l.managedNoNodes,
              textAlign: TextAlign.center,
              style: OtType.display(19),
            ),
          ],
        );
        actions = [_ClockNote(text: l.managedServerClockNote)];
      case ManagedPhase.preparing:
        body = s.slow
            ? const FailureView(kind: FailureKind.slowAgent)
            : WaitingView(
                title: l.managedPreparing, body: l.managedPreparingBody);
        actions = [GhostButton(label: l.commonCancel, onPressed: c.cancel)];
      case ManagedPhase.connecting:
        body = WaitingView(
            title: l.managedConnecting, body: l.managedConnectingBody);
        actions = [SecondaryButton(label: l.commonCancel, onPressed: c.cancel)];
      case ManagedPhase.connected:
        body = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: StatusPill(
                  label: l.managedConnected, kind: PillKind.success),
            ),
            const SizedBox(height: 20),
            Center(
              child: CountdownRing(
                remaining: s.remaining ?? Duration.zero,
                label: l.managedRemaining,
              ),
            ),
            const SizedBox(height: 16),
            Text(l.managedServerClockNote,
                textAlign: TextAlign.center, style: OtType.bodySmall),
            const SizedBox(height: 18),
            InfoRows(rows: [
              if (s.serverLabel != null) (l.managedServer, rowValue(s.serverLabel!)),
              if (s.tunnelAddress != null)
                (l.managedTunnelAddress, rowValue(s.tunnelAddress!)),
            ]),
          ],
        );
        actions = [
          SecondaryButton(
            label: l.managedDisconnect,
            icon: Icons.power_settings_new_rounded,
            onPressed: c.disconnect,
          ),
        ];
      case ManagedPhase.activeDisconnected:
        body = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CountdownRing(
              remaining: s.remaining ?? Duration.zero,
              label: l.managedRemaining,
              dimmed: true,
            ),
            const SizedBox(height: 16),
            StatusPill(label: l.managedIdleStatus, kind: PillKind.idle),
            const SizedBox(height: 12),
            Text(l.managedActiveNotConnected,
                textAlign: TextAlign.center, style: OtType.title),
          ],
        );
        actions = [
          PrimaryButton(
            label: l.managedReconnect,
            busy: s.busy,
            onPressed: c.reconnect,
          ),
        ];
      case ManagedPhase.expired:
        body = NoticeView(
          icon: Icons.timer_off_outlined,
          color: OtColors.accentLight,
          title: l.managedExpiredTitle,
          body: l.managedExpiredBody,
        );
        actions = [
          SecondaryButton(
              label: l.commonHome, onPressed: () => context.go(Routes.home)),
        ];
      case ManagedPhase.failure:
        body = FailureView(kind: s.failure ?? FailureKind.unknown);
        actions = [
          PrimaryButton(label: l.commonRetry, onPressed: c.retry),
          GhostButton(
              label: l.commonHome, onPressed: () => context.go(Routes.home)),
        ];
    }

    return OtScaffold(
      title: l.managedTitle,
      onBack: () => goBack(context, Routes.home),
      glow: 1,
      centerBody: true,
      body: body,
      actions: actions,
    );
  }
}

class _ClockNote extends StatelessWidget {
  const _ClockNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => GlassCard(
        radius: 20,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.schedule_rounded,
                size: 22, color: OtColors.accentLight),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: OtType.bodySmall)),
          ],
        ),
      );
}
