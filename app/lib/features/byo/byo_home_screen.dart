import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/secrets_mask.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/byo_store.dart';
import '../../platform/vpn_channel.dart';
import '../../ui/failure_view.dart';
import '../../ui/nav.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'byo_controller.dart';

/// Главный экран BYO: пусто или сохранённый конфиг. Таймера нет.
class ByoHomeScreen extends ConsumerWidget {
  const ByoHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(byoControllerProvider);
    final c = ref.read(byoControllerProvider.notifier);

    Widget body;
    var actions = <Widget>[];
    var center = true;

    if (s.loading) {
      body = const Center(
        child: CircularProgressIndicator(color: OtColors.accentBright),
      );
    } else if (s.failure != null) {
      body = FailureView(kind: s.failure!);
      actions = [
        PrimaryButton(label: l.commonRetry, onPressed: c.clearFailure),
      ];
    } else if (s.summary == null) {
      body = NoticeView(
        icon: Icons.add_rounded,
        color: OtColors.accentBright,
        title: l.byoEmptyTitle,
        body: l.byoEmptyBody,
      );
      actions = [
        PrimaryButton(
          label: l.byoPaste,
          icon: Icons.content_paste_rounded,
          onPressed: () => context.push(Routes.byoPaste),
        ),
        SecondaryButton(
          label: l.byoFile,
          icon: Icons.description_outlined,
          onPressed: () => _importFile(context, ref),
        ),
        SecondaryButton(
          label: l.byoQr,
          icon: Icons.qr_code_scanner_rounded,
          onPressed: () => context.push(Routes.byoQr),
        ),
      ];
    } else {
      center = false;
      body = _SavedConfig(summary: s.summary!, tunnel: s.tunnel);
      actions = [
        if (s.tunnel == TunnelStatus.disconnected)
          PrimaryButton(
            label: l.byoConnect,
            busy: s.busy,
            onPressed: c.connect,
          )
        else
          SecondaryButton(
            label: l.byoDisconnect,
            icon: Icons.power_settings_new_rounded,
            onPressed: c.disconnect,
          ),
        GhostButton(
          label: l.byoDelete,
          color: OtColors.dangerText,
          onPressed: () async {
            final ok = await showGlassConfirm(
              context,
              title: l.byoDeleteTitle,
              body: l.byoDeleteBody,
              confirm: l.byoDeleteConfirm,
              cancel: l.commonCancel,
            );
            if (ok) await c.delete();
          },
        ),
      ];
    }

    return OtScaffold(
      title: l.byoTitle,
      onBack: () => goBack(context, Routes.home),
      trailing: OtTag(l.byoOfflineTag, color: OtColors.cyan),
      glow: 2,
      centerBody: center,
      body: body,
      actions: actions,
    );
  }

  Future<void> _importFile(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final r = await ref.read(byoControllerProvider.notifier).importFile();
    if (r is ByoRejected && r.reason != ByoRejectReason.cancelled) {
      messenger.showSnackBar(SnackBar(
        content: Text(r.reason == ByoRejectReason.tooLarge
            ? l.byoTooLarge
            : l.byoInvalid),
      ));
    }
  }
}

class _SavedConfig extends StatelessWidget {
  const _SavedConfig({required this.summary, required this.tunnel});

  final ByoSummary summary;
  final TunnelStatus tunnel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (pillLabel, pillKind) = switch (tunnel) {
      TunnelStatus.connected => (l.byoConnected, PillKind.success),
      TunnelStatus.connecting => (l.byoConnecting, PillKind.progress),
      TunnelStatus.disconnected => (l.byoNotConnected, PillKind.idle),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        GlassCard(
          strong: true,
          radius: 28,
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.byoProtocol.toUpperCase(),
                            style: OtType.tag.copyWith(letterSpacing: 1)),
                        const SizedBox(height: 4),
                        Text(l.byoSavedTitle, style: OtType.display(22)),
                      ],
                    ),
                  ),
                  StatusPill(label: pillLabel, kind: pillKind),
                ],
              ),
              const SizedBox(height: 16),
              _row(l.byoServer, Text(summary.endpoint, style: OtType.rowValue)),
              _row(l.byoTunnelAddress,
                  Text(summary.tunnelAddress, style: OtType.rowValue)),
              _row(
                l.byoPrivateKey,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline_rounded,
                        size: 14, color: OtColors.accentLight),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(kSecretMarker,
                          key: const Key('byo-key-mask'),
                          style: OtType.rowValue.copyWith(letterSpacing: 2)),
                    ),
                  ],
                ),
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(l.byoNoTimer, style: OtType.bodySmall),
      ],
    );
  }

  Widget _row(String label, Widget value, {bool last = false}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: OtColors.divider)),
        ),
        child: Row(
          children: [
            Text(label, style: OtType.rowLabel),
            const SizedBox(width: 12),
            Expanded(
              child: Align(alignment: Alignment.centerRight, child: value),
            ),
          ],
        ),
      );
}
