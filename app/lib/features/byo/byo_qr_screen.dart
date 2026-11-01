import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/byo_store.dart';
import '../../ui/nav.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'byo_controller.dart';

/// Импорт по QR. Камеру и разбор открывает Kotlin (importQr);
/// Flutter получает только endpoint и туннельный адрес.
class ByoQrScreen extends ConsumerStatefulWidget {
  const ByoQrScreen({super.key});

  @override
  ConsumerState<ByoQrScreen> createState() => _ByoQrScreenState();
}

class _ByoQrScreenState extends ConsumerState<ByoQrScreen> {
  bool _busy = false;
  ByoRejectReason? _error;

  Future<void> _scan() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await ref.read(byoControllerProvider.notifier).importQr();
    if (!mounted) return;
    switch (r) {
      case ByoImported():
        goBack(context, Routes.byo);
      case ByoRejected(:final reason):
        setState(() {
          _busy = false;
          _error = reason == ByoRejectReason.cancelled ? null : reason;
        });
    }
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
      title: l.byoQrTitle,
      onBack: () => goBack(context, Routes.byo),
      glow: 2,
      centerBody: true,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassCard(
            radius: 24,
            padding: const EdgeInsets.all(48),
            child: SizedBox.square(
              dimension: 200,
              child: CustomPaint(painter: _ViewfinderPainter()),
            ),
          ),
          const SizedBox(height: 24),
          Text(l.byoQrHint, textAlign: TextAlign.center, style: OtType.title),
          const SizedBox(height: 8),
          Text(l.byoQrNote, textAlign: TextAlign.center, style: OtType.bodySmall),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error,
                textAlign: TextAlign.center,
                style: OtType.bodyStrong.copyWith(color: OtColors.dangerText)),
          ],
        ],
      ),
      actions: [
        PrimaryButton(
          label: l.byoQrStart,
          icon: Icons.qr_code_scanner_rounded,
          busy: _busy,
          onPressed: _scan,
        ),
        GhostButton(
          label: l.commonCancel,
          onPressed: () => goBack(context, Routes.byo),
        ),
      ],
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const len = 36.0;
    const r = 16.0;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = OtColors.accentBright;
    final w = size.width;
    final h = size.height;
    final corners = [
      Path()
        ..moveTo(0, len)
        ..lineTo(0, r)
        ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
        ..lineTo(len, 0),
      Path()
        ..moveTo(w - len, 0)
        ..lineTo(w - r, 0)
        ..arcToPoint(Offset(w, r), radius: const Radius.circular(r))
        ..lineTo(w, len),
      Path()
        ..moveTo(w, h - len)
        ..lineTo(w, h - r)
        ..arcToPoint(Offset(w - r, h), radius: const Radius.circular(r))
        ..lineTo(w - len, h),
      Path()
        ..moveTo(len, h)
        ..lineTo(r, h)
        ..arcToPoint(Offset(0, h - r), radius: const Radius.circular(r))
        ..lineTo(0, h - len),
    ];
    for (final path in corners) {
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
