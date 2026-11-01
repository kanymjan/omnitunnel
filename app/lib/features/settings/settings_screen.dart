import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/settings.dart';
import '../../data/api/omni_api.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/nav.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Настройки: язык, смена режима, приватность, удаление данных (US-OT08).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;
  bool _deleted = false;

  Future<void> _deleteData() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showGlassConfirm(
      context,
      title: l.settingsDeleteTitle,
      body: l.settingsDeleteBody,
      confirm: l.settingsDeleteConfirm,
      cancel: l.commonCancel,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(vpnChannelProvider).disconnect();
      await ref.read(omniApiProvider).deleteInstallation();
      await ref.read(installationKeysProvider).reset();
      await ref.read(settingsProvider.notifier).resetInstallation();
      if (mounted) setState(() => _deleted = true);
    } on ApiNotInContract {
      messenger.showSnackBar(SnackBar(content: Text(l.settingsDeleteUnavailable)));
    } on ApiOffline {
      messenger.showSnackBar(SnackBar(content: Text(l.failOfflineTitle)));
    } on ApiFailure {
      messenger.showSnackBar(SnackBar(content: Text(l.failServerTitle)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final lang = ref.watch(settingsProvider.select((s) => s.languageCode)) ??
        Localizations.localeOf(context).languageCode;

    if (_deleted) {
      return OtScaffold(
        title: l.settingsTitle,
        centerBody: true,
        body: NoticeView(
          icon: Icons.check_rounded,
          color: OtColors.success,
          title: l.settingsDeletedTitle,
          body: l.settingsDeletedBody,
        ),
        actions: [
          SecondaryButton(
              label: l.commonHome, onPressed: () => context.go(Routes.home)),
        ],
      );
    }

    return OtScaffold(
      title: l.settingsTitle,
      onBack: () => goBack(context, Routes.home),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Text(l.settingsLanguage, style: OtType.label),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _LangChip(
                  label: l.languageRussian,
                  selected: lang == 'ru',
                  onTap: () =>
                      ref.read(settingsProvider.notifier).setLanguage('ru'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LangChip(
                  label: l.languageKyrgyz,
                  selected: lang == 'ky',
                  onTap: () =>
                      ref.read(settingsProvider.notifier).setLanguage('ky'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _LinkRow(label: l.settingsMode, onTap: () => context.go(Routes.home)),
          const SizedBox(height: 10),
          _LinkRow(
            label: l.settingsPrivacy,
            onTap: () => context.push(Routes.settingsPrivacy),
          ),
          const SizedBox(height: 28),
          SecondaryButton(
            label: l.settingsDeleteData,
            icon: Icons.delete_outline_rounded,
            color: OtColors.dangerText,
            onPressed: _busy ? null : _deleteData,
          ),
          const SizedBox(height: 12),
          Text(l.settingsByoNote, style: OtType.bodySmall),
        ],
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: true,
        child: GlassCard(
          onTap: onTap,
          radius: 16,
          strong: selected,
          borderColor: selected ? OtColors.accentBright : null,
          borderWidth: selected ? 2 : 1,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Center(child: Text(label, style: OtType.bodyStrong)),
        ),
      );
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GlassCard(
        onTap: onTap,
        radius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Expanded(child: Text(label, style: OtType.bodyStrong)),
            const Icon(Icons.chevron_right_rounded, color: OtColors.accentLight),
          ],
        ),
      );
}
