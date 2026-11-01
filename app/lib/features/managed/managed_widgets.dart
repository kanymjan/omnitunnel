import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/config.dart';
import '../../ui/theme.dart';

/// mm:ss, округление вверх: 24:12.6 показывается как 24:13.
String formatRemaining(Duration d) {
  final total = (d.inMilliseconds + 999) ~/ 1000;
  final mm = (total ~/ 60).toString().padLeft(2, '0');
  final ss = (total % 60).toString().padLeft(2, '0');
  return '$mm:$ss';
}

/// Большой светящийся шар «получить доступ». От него расходятся волны.
class AccessOrb extends ConsumerStatefulWidget {
  const AccessOrb({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  ConsumerState<AccessOrb> createState() => _AccessOrbState();
}

class _AccessOrbState extends ConsumerState<AccessOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2800));

  @override
  void initState() {
    super.initState();
    if (!ref.read(reduceMotionProvider)) _c.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = 200.0;
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size + 80,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (enabled)
              AnimatedBuilder(
                animation: _c,
                builder: (context, _) => Stack(
                  alignment: Alignment.center,
                  children: [
                    for (final phase in const [0.0, 0.5])
                      _Wave(t: (_c.value + phase) % 1, size: size),
                  ],
                ),
              ),
            AnimatedOpacity(
              opacity: enabled ? 1 : 0.6,
              duration: const Duration(milliseconds: 200),
              child: GestureDetector(
                key: const Key('access-orb'),
                onTap: widget.onTap,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      center: Alignment(-0.3, -0.4),
                      colors: [OtColors.accentLight, OtColors.accent, OtColors.navy],
                      stops: [0, 0.4, 1],
                    ),
                    border: Border.all(color: const Color(0x40FFFFFF)),
                    boxShadow: [
                      BoxShadow(
                        color: OtColors.accentBright.withValues(alpha: 0.6),
                        blurRadius: 80,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.power_settings_new_rounded,
                      size: 64, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Wave extends StatelessWidget {
  const _Wave({required this.t, required this.size});

  final double t;
  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size * (1 + 0.4 * t),
          height: size * (1 + 0.4 * t),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: OtColors.accentBright.withValues(alpha: 0.6 * (1 - t)),
              width: 2,
            ),
          ),
        ),
      );
}

/// Кольцо обратного отсчёта. Показывает остаток по часам сервера;
/// выдачу оно не продлевает и не завершает.
class CountdownRing extends StatelessWidget {
  const CountdownRing({
    super.key,
    required this.remaining,
    required this.label,
    this.dimmed = false,
  });

  final Duration remaining;
  final String label;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final fraction =
        (remaining.inMilliseconds / kTrialLength.inMilliseconds).clamp(0.0, 1.0);
    final text = formatRemaining(remaining);
    return Semantics(
      label: '$label $text',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: 250,
        child: CustomPaint(
          painter: _RingPainter(fraction: fraction, dimmed: dimmed),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(36),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(text,
                        key: const Key('countdown-text'),
                        style: OtType.timer(48).copyWith(
                            color: dimmed ? OtColors.muted : OtColors.text)),
                    const SizedBox(height: 6),
                    Text(label, style: OtType.body),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.fraction, required this.dimmed});

  final double fraction;
  final bool dimmed;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final c = size.center(Offset.zero);
    final r = size.width / 2 - stroke;
    final rect = Rect.fromCircle(center: c, radius: r);

    canvas.drawCircle(
      c,
      r,
      Paint()..color = const Color(0x8C0A0F24),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = const Color(0x14FFFFFF),
    );
    if (fraction <= 0) return;

    final sweep = 2 * math.pi * fraction;
    final shader = const SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: 3 * math.pi / 2,
      colors: [OtColors.cyan, OtColors.accentBright, OtColors.accent],
    ).createShader(rect);
    final alpha = dimmed ? 0.45 : 1.0;

    if (!dimmed) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke + 10
          ..strokeCap = StrokeCap.round
          ..color = OtColors.accentBright.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }
    canvas.saveLayer(rect.inflate(stroke),
        Paint()..color = Colors.white.withValues(alpha: alpha));
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = shader,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.dimmed != dimmed;
}

/// Ожидание: кольцо загрузки и два текста.
class WaitingView extends StatelessWidget {
  const WaitingView({super.key, required this.title, this.body});

  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 180,
            height: 180,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: OtColors.glass,
              border: Border.all(color: OtColors.glassBorder),
              boxShadow: [
                BoxShadow(
                  color: OtColors.accent.withValues(alpha: 0.45),
                  blurRadius: 60,
                ),
              ],
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 4,
              color: OtColors.accentBright,
              strokeCap: StrokeCap.round,
            ),
          ),
          const SizedBox(height: 28),
          Text(title, textAlign: TextAlign.center, style: OtType.noticeTitle),
          if (body != null) ...[
            const SizedBox(height: 8),
            Text(body!, textAlign: TextAlign.center, style: OtType.body),
          ],
        ],
      );
}
