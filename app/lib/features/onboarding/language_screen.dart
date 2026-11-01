import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/settings.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Первый запуск: выбор языка. Заголовок сразу на обоих языках.
class LanguageScreen extends ConsumerStatefulWidget {
  const LanguageScreen({super.key});

  @override
  ConsumerState<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends ConsumerState<LanguageScreen> {
  String? _picked;

  Future<void> _next(String code) async {
    await ref.read(settingsProvider.notifier).setLanguage(code);
    if (mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ru = lookupAppLocalizations(const Locale('ru'));
    final ky = lookupAppLocalizations(const Locale('ky'));
    final current = _picked ?? Localizations.localeOf(context).languageCode;
    final picked = current == 'ky' ? 'ky' : 'ru';
    return OtScaffold(
      leading: const TunnelLogo(size: 34),
      title: l.appName,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 28),
          Text(ru.languageTitle, style: OtType.display(28)),
          const SizedBox(height: 6),
          Text(ky.languageTitle, style: OtType.body.copyWith(fontSize: 17)),
          const SizedBox(height: 32),
          _LanguageOption(
            label: l.languageRussian,
            selected: picked == 'ru',
            onTap: () => setState(() => _picked = 'ru'),
          ),
          const SizedBox(height: 12),
          _LanguageOption(
            label: l.languageKyrgyz,
            selected: picked == 'ky',
            onTap: () => setState(() => _picked = 'ky'),
          ),
        ],
      ),
      actions: [
        PrimaryButton(
          label: picked == 'ky' ? ky.languageNext : ru.languageNext,
          onPressed: () => _next(picked),
        ),
      ],
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
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
          radius: 20,
          strong: selected,
          borderColor: selected ? OtColors.accentBright : null,
          borderWidth: selected ? 2 : 1,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Row(
            children: [
              Expanded(child: Text(label, style: OtType.title)),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? OtColors.accentBright : null,
                  border: Border.all(
                    color: selected ? OtColors.accentBright : OtColors.glassBorder,
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      );
}
