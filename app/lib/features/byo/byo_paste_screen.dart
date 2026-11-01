import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../core/secrets_mask.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/byo_store.dart';
import '../../ui/nav.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'byo_controller.dart';

/// Вставка конфига из буфера обмена. Пользователь не набирает ключ
/// в поле ввода: текст берётся из буфера и показывается только
/// с замазанными PrivateKey и PresharedKey.
class ByoPasteScreen extends ConsumerStatefulWidget {
  const ByoPasteScreen({super.key});

  @override
  ConsumerState<ByoPasteScreen> createState() => _ByoPasteScreenState();
}

class _ByoPasteScreenState extends ConsumerState<ByoPasteScreen> {
  String? _raw;
  bool _empty = false;
  bool _busy = false;
  ByoRejectReason? _error;

  @override
  void dispose() {
    _raw = null;
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (!mounted) return;
    setState(() {
      _empty = text == null || text.isEmpty;
      _raw = _empty ? null : text;
      _error = null;
    });
  }

  Future<void> _save() async {
    final raw = _raw;
    if (raw == null) return;
    setState(() => _busy = true);
    final r = await ref.read(byoControllerProvider.notifier).importText(raw);
    if (!mounted) return;
    switch (r) {
      case ByoImported():
        _raw = null;
        goBack(context, Routes.byo);
      case ByoRejected(:final reason):
        setState(() {
          _busy = false;
          _error = reason;
        });
    }
  }

  String _preview(String raw) {
    final lines = maskSecrets(raw).split('\n');
    return lines.length > 30 ? '${lines.take(30).join('\n')}\n…' : lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final error = switch (_error) {
      ByoRejectReason.tooLarge => l.byoTooLarge,
      ByoRejectReason.invalid => l.byoInvalid,
      _ => null,
    };
    return OtScaffold(
      title: l.byoTitle,
      onBack: () => goBack(context, Routes.byo),
      glow: 2,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Text(l.byoPasteTitle, style: OtType.display(22)),
          const SizedBox(height: 20),
          if (_raw == null)
            GlassCard(
              key: const Key('byo-paste-from-clipboard'),
              radius: 20,
              onTap: _paste,
              child: Row(
                children: [
                  const Icon(Icons.content_paste_rounded,
                      color: OtColors.accentLight),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(l.byoPasteFromClipboard, style: OtType.bodyStrong),
                  ),
                ],
              ),
            )
          else
            GlassCard(
              radius: 20,
              borderColor: error != null ? OtColors.danger : OtColors.accentBright,
              borderWidth: 2,
              child: Text(
                _preview(_raw!),
                key: const Key('byo-masked-preview'),
                style: OtType.mono,
              ),
            ),
          if (_empty) ...[
            const SizedBox(height: 12),
            Text(l.byoPasteEmpty,
                style: OtType.bodySmall.copyWith(color: OtColors.warning)),
          ],
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error,
                style: OtType.bodyStrong.copyWith(color: OtColors.dangerText)),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.lock_outline_rounded,
                  size: 16, color: OtColors.accentLight),
              const SizedBox(width: 8),
              Expanded(child: Text(l.byoPasteKeyNote, style: OtType.bodySmall)),
            ],
          ),
        ],
      ),
      actions: [
        PrimaryButton(
          label: l.byoSave,
          busy: _busy,
          onPressed: _raw == null ? null : _save,
        ),
        GhostButton(
          label: l.commonCancel,
          onPressed: () => goBack(context, Routes.byo),
        ),
      ],
    );
  }
}
