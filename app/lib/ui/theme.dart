import 'package:flutter/material.dart';

/// Цвета концепта «стекло и свет».
abstract final class OtColors {
  static const base = Color(0xFF060A18);
  static const text = Color(0xFFF2F5FF);
  static const muted = Color(0xFFA8B3D1);
  static const soft = Color(0xFFC9D3F2);
  static const accent = Color(0xFF3B5BDB);
  static const accentBright = Color(0xFF5B7CFA);
  static const accentLight = Color(0xFF8EA6FF);
  static const accentDeep = Color(0xFF1E40AF);
  static const navy = Color(0xFF1E2A6B);
  static const indigo = Color(0xFF4338CA);
  static const cyan = Color(0xFF7DD3FC);
  static const success = Color(0xFF34C38F);
  static const successText = Color(0xFF6EE7B7);
  static const warning = Color(0xFFF2B84B);
  static const danger = Color(0xFFF06A6A);
  static const dangerText = Color(0xFFFCA5A5);

  static const glass = Color(0x12FFFFFF);
  static const glassStrong = Color(0x1CFFFFFF);
  static const glassBorder = Color(0x24FFFFFF);
  static const divider = Color(0x14FFFFFF);
}

/// Шрифты переменные: толщину задаём через ось wght, а не только fontWeight.
TextStyle _style(String family, double size, int weight,
        {Color color = OtColors.text, double height = 1.35, double? spacing}) =>
    TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: FontWeight.values[(weight ~/ 100) - 1],
      fontVariations: [FontVariation('wght', weight.toDouble())],
      color: color,
      height: height,
      letterSpacing: spacing,
    );

abstract final class OtType {
  static TextStyle display([double size = 28]) =>
      _style('Unbounded', size, 600, height: 1.18);
  static TextStyle wordmark([double size = 18]) =>
      _style('Unbounded', size, 600, spacing: 0.2);
  static TextStyle timer([double size = 48]) =>
      _style('Unbounded', size, 600, height: 1.0, spacing: -1);
  static final TextStyle title = _style('Onest', 18, 600);
  static final TextStyle headerTitle = _style('Onest', 17, 600);
  static final TextStyle noticeTitle = _style('Onest', 20, 600, height: 1.3);
  static final TextStyle body = _style('Onest', 15, 400, color: OtColors.muted, height: 1.45);
  static final TextStyle bodySmall =
      _style('Onest', 13, 400, color: OtColors.muted, height: 1.45);
  static final TextStyle bodyStrong = _style('Onest', 15, 500);
  static final TextStyle label = _style('Onest', 13, 500, color: OtColors.soft);
  static final TextStyle tag = _style('Onest', 12, 500, color: OtColors.accentLight);
  static final TextStyle button = _style('Onest', 16, 600);
  static final TextStyle rowLabel = _style('Onest', 14, 400, color: OtColors.muted);
  static final TextStyle rowValue = _style('Onest', 14, 500);
  static const TextStyle mono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 13,
    height: 1.5,
    color: OtColors.text,
  );
}

ThemeData buildOtTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Onest',
  );
  return base.copyWith(
    scaffoldBackgroundColor: OtColors.base,
    colorScheme: const ColorScheme.dark(
      primary: OtColors.accentBright,
      onPrimary: Colors.white,
      secondary: OtColors.cyan,
      surface: OtColors.base,
      onSurface: OtColors.text,
      error: OtColors.danger,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: OtColors.text,
      displayColor: OtColors.text,
      fontFamily: 'Onest',
    ),
  );
}
