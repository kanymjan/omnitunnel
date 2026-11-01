import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../l10n/app_localizations.dart';
import 'theme.dart';

/// Тёмный фон с медленно плывущими светящимися пятнами.
class GlowBackground extends ConsumerStatefulWidget {
  const GlowBackground({super.key, required this.child, this.variant = 0});

  final Widget child;
  final int variant;

  @override
  ConsumerState<GlowBackground> createState() => _GlowBackgroundState();
}

class _GlowBackgroundState extends ConsumerState<GlowBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 16));

  @override
  void initState() {
    super.initState();
    if (!ref.read(reduceMotionProvider)) _c.repeat(reverse: true);
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

  static const _layouts = <List<(Color, double, Alignment)>>[
    [
      (OtColors.accentDeep, 0.55, Alignment(-1.1, -0.9)),
      (OtColors.indigo, 0.42, Alignment(1.2, 0.2)),
      (OtColors.cyan, 0.16, Alignment(-0.4, 1.2)),
    ],
    [
      (OtColors.accentDeep, 0.55, Alignment(-0.9, -0.1)),
      (OtColors.indigo, 0.38, Alignment(1.2, -1.0)),
      (OtColors.cyan, 0.16, Alignment(1.0, 1.1)),
    ],
    [
      (OtColors.cyan, 0.24, Alignment(1.1, -1.0)),
      (OtColors.accentDeep, 0.5, Alignment(-1.2, 0.6)),
      (OtColors.indigo, 0.3, Alignment(0.6, 1.2)),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    final blobs = _layouts[widget.variant % _layouts.length];
    return ColoredBox(
      color: OtColors.base,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = Curves.easeInOut.transform(_c.value);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    for (var i = 0; i < blobs.length; i++)
                      Align(
                        alignment: blobs[i].$3,
                        child: Transform.translate(
                          offset: Offset(
                            math.sin((t + i) * math.pi) * 24,
                            math.cos((t + i) * math.pi) * 28,
                          ),
                          child: _Blob(color: blobs[i].$1, opacity: blobs[i].$2),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.opacity});

  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: 460,
          height: 460,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ]),
          ),
        ),
      );
}

/// Полупрозрачная карточка с размытием фона («матовое стекло»).
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
    this.onTap,
    this.strong = false,
    this.borderColor,
    this.borderWidth = 1,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final bool strong;
  final Color? borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: strong ? OtColors.glassStrong : OtColors.glass,
        borderRadius: br,
        border: Border.all(
            color: borderColor ?? OtColors.glassBorder, width: borderWidth),
      ),
      child: child,
    );
    if (onTap != null) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(borderRadius: br, onTap: onTap, child: content),
      );
    }
    return ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: content,
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.danger = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool danger;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final br = BorderRadius.circular(18);
    final colors = danger
        ? const [Color(0xFFF06A6A), Color(0xFFB91C1C)]
        : const [OtColors.accentBright, OtColors.accentDeep];
    return Semantics(
      button: true,
      enabled: enabled,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.55,
        duration: const Duration(milliseconds: 150),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: br,
            gradient: LinearGradient(colors: colors),
            border: Border.all(color: const Color(0x33FFFFFF)),
            boxShadow: [
              BoxShadow(
                color: colors.last.withValues(alpha: 0.45),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: br,
              onTap: enabled ? onPressed : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Center(
                    child: busy
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.4, color: Colors.white),
                          )
                        : _ButtonLabel(
                            label: label,
                            icon: icon,
                            style: OtType.button.copyWith(color: Colors.white),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        enabled: onPressed != null,
        child: GlassCard(
          radius: 18,
          strong: true,
          padding: EdgeInsets.zero,
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Center(
                child: _ButtonLabel(
                  label: label,
                  icon: icon,
                  style: OtType.button.copyWith(color: color ?? OtColors.text),
                ),
              ),
            ),
          ),
        ),
      );
}

class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = OtColors.accentLight,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        enabled: onPressed != null,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: OtType.button.copyWith(fontSize: 15, color: color),
                ),
              ),
            ),
          ),
        ),
      );
}

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel({required this.label, required this.style, this.icon});

  final String label;
  final TextStyle style;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final text = Text(label, textAlign: TextAlign.center, style: style);
    if (icon == null) return text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: style.color),
        const SizedBox(width: 10),
        Flexible(child: text),
      ],
    );
  }
}

/// Квадратная стеклянная кнопка с иконкой (назад, настройки).
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          label: tooltip,
          onTap: onPressed,
          excludeSemantics: true,
          child: GlassCard(
            radius: 14,
            padding: EdgeInsets.zero,
            onTap: onPressed,
            child: SizedBox.square(
              dimension: 44,
              child: Icon(icon, size: 20, color: OtColors.soft),
            ),
          ),
        ),
      );
}

enum PillKind { idle, progress, success }

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.kind});

  final String label;
  final PillKind kind;

  @override
  Widget build(BuildContext context) {
    final (bg, border, fg) = switch (kind) {
      PillKind.success => (
          OtColors.success.withValues(alpha: 0.14),
          OtColors.success.withValues(alpha: 0.35),
          OtColors.successText,
        ),
      PillKind.progress => (
          OtColors.accentBright.withValues(alpha: 0.16),
          OtColors.accentBright.withValues(alpha: 0.35),
          OtColors.accentLight,
        ),
      PillKind.idle => (OtColors.glass, OtColors.glassBorder, OtColors.soft),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kind == PillKind.idle ? null : fg,
              border: kind == PillKind.idle
                  ? Border.all(color: OtColors.muted, width: 1.5)
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(label, style: OtType.label.copyWith(color: fg)),
          ),
        ],
      ),
    );
  }
}

class OtTag extends StatelessWidget {
  const OtTag(this.label, {super.key, this.color = OtColors.accentLight});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label, style: OtType.tag.copyWith(color: color)),
      );
}

/// Строки «название — значение» в стеклянной карточке.
class InfoRows extends StatelessWidget {
  const InfoRows({super.key, required this.rows});

  final List<(String, Widget)> rows;

  @override
  Widget build(BuildContext context) => GlassCard(
        radius: 22,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: i == rows.length - 1
                      ? null
                      : const Border(
                          bottom: BorderSide(color: OtColors.divider)),
                ),
                child: Row(
                  children: [
                    Text(rows[i].$1, style: OtType.rowLabel),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Align(
                          alignment: Alignment.centerRight, child: rows[i].$2),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
}

Widget rowValue(String v) =>
    Text(v, style: OtType.rowValue, textAlign: TextAlign.right);

/// Значок, заголовок и текст по центру — для пустых состояний и сбоев.
class NoticeView extends StatelessWidget {
  const NoticeView({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: OtColors.glassStrong,
              border: Border.all(color: OtColors.glassBorder),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 36),
              ],
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 20),
          Text(title, textAlign: TextAlign.center, style: OtType.noticeTitle),
          const SizedBox(height: 10),
          Text(body, textAlign: TextAlign.center, style: OtType.body),
        ],
      );
}

/// Каркас экрана: фон, шапка, прокручиваемое тело, кнопки внизу.
class OtScaffold extends StatelessWidget {
  const OtScaffold({
    super.key,
    required this.body,
    this.title,
    this.onBack,
    this.leading,
    this.trailing,
    this.actions = const [],
    this.glow = 0,
    this.centerBody = false,
  });

  final Widget body;
  final String? title;
  final VoidCallback? onBack;
  final Widget? leading;
  final Widget? trailing;
  final List<Widget> actions;
  final int glow;
  final bool centerBody;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasHeader =
        title != null || onBack != null || leading != null || trailing != null;
    return Scaffold(
      backgroundColor: OtColors.base,
      body: GlowBackground(
        variant: glow,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: Column(
              children: [
                if (hasHeader)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        if (onBack != null) ...[
                          GlassIconButton(
                            icon: Icons.arrow_back_ios_new_rounded,
                            tooltip: l.commonBack,
                            onPressed: onBack!,
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (leading != null) ...[
                          leading!,
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: title == null
                              ? const SizedBox()
                              : Text(title!,
                                  style: OtType.headerTitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                        ),
                        if (trailing != null) trailing!,
                      ],
                    ),
                  ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: c.maxHeight),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: centerBody
                              ? MainAxisAlignment.center
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [body],
                        ),
                      ),
                    ),
                  ),
                ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    actions[i],
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Знак «Туннель»: кольца уходят вглубь, в конце свет.
class TunnelLogo extends StatelessWidget {
  const TunnelLogo({super.key, this.size = 34});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: CustomPaint(
          size: Size.square(size),
          painter: const _TunnelLogoPainter(),
        ),
      );
}

class _TunnelLogoPainter extends CustomPainter {
  const _TunnelLogoPainter();

  static const _rings = <(double, double, double, double, Color, double)>[
    (60, 60, 52, 5.5, OtColors.accent, 1),
    (65, 56, 39, 5, OtColors.accentBright, 0.85),
    (69, 53, 26, 4.5, OtColors.accentLight, 0.7),
    (72, 51, 14, 4, Color(0xFFC3D0FF), 0.6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 120;
    for (final (cx, cy, r, w, color, a) in _rings) {
      canvas.drawCircle(
        Offset(cx * s, cy * s),
        r * s,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * s
          ..color = color.withValues(alpha: a),
      );
    }
    final c = Offset(74 * s, 50 * s);
    canvas.drawCircle(
      c,
      7 * s,
      Paint()
        ..shader = const RadialGradient(colors: [Colors.white, OtColors.cyan])
            .createShader(Rect.fromCircle(center: c, radius: 7 * s)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Подтверждение в стеклянном окне. true — пользователь подтвердил.
Future<bool> showGlassConfirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirm,
  required String cancel,
  bool danger = true,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0xB3060A18),
    builder: (context) => Dialog(
      backgroundColor: const Color(0xFF121A36),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: OtColors.glassBorder),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: OtType.noticeTitle),
            const SizedBox(height: 12),
            Text(body, style: OtType.body),
            const SizedBox(height: 20),
            PrimaryButton(
              label: confirm,
              danger: danger,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 4),
            GhostButton(
              label: cancel,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    ),
  );
  return ok ?? false;
}
