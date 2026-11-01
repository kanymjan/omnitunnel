import 'package:flutter/material.dart';

import '../data/api/omni_api.dart';
import '../l10n/app_localizations.dart';
import 'theme.dart';
import 'widgets.dart';

/// Сбои MOB-501 и общие ошибки. Тексты не обещают того, что не измерено.
enum FailureKind {
  permissionDenied,
  permissionDeniedPermanently,
  offline,
  serverDown,
  noCapacity,
  slowAgent,
  rateLimited,
  unknown,
}

/// Перевод ошибки API в вид сбоя на экране.
FailureKind failureFromApi(Object e) => switch (e) {
      ApiOffline() => FailureKind.offline,
      ApiUnavailable() => FailureKind.serverDown,
      ApiRejected(code: 'NO_CAPACITY') => FailureKind.noCapacity,
      ApiRejected(status: 429) => FailureKind.rateLimited,
      _ => FailureKind.unknown,
    };

class FailureView extends StatelessWidget {
  const FailureView({super.key, required this.kind});

  final FailureKind kind;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (icon, color, title, body) = switch (kind) {
      FailureKind.permissionDenied => (
          Icons.vpn_key_off_outlined,
          OtColors.warning,
          l.failPermissionTitle,
          l.failPermissionBody,
        ),
      FailureKind.permissionDeniedPermanently => (
          Icons.block_rounded,
          OtColors.danger,
          l.failPermissionPermanentTitle,
          l.failPermissionPermanentBody,
        ),
      FailureKind.offline => (
          Icons.wifi_off_rounded,
          OtColors.danger,
          l.failOfflineTitle,
          l.failOfflineBody,
        ),
      FailureKind.serverDown => (
          Icons.cloud_off_rounded,
          OtColors.warning,
          l.failServerTitle,
          l.failServerBody,
        ),
      FailureKind.noCapacity => (
          Icons.hourglass_empty_rounded,
          OtColors.accentLight,
          l.failCapacityTitle,
          l.failCapacityBody,
        ),
      FailureKind.slowAgent => (
          Icons.more_horiz_rounded,
          OtColors.accentLight,
          l.failSlowTitle,
          l.failSlowBody,
        ),
      FailureKind.rateLimited => (
          Icons.timer_outlined,
          OtColors.warning,
          l.failRateLimitedTitle,
          l.failRateLimitedBody,
        ),
      FailureKind.unknown => (
          Icons.error_outline_rounded,
          OtColors.danger,
          l.failUnknownTitle,
          l.failUnknownBody,
        ),
    };
    return NoticeView(icon: icon, color: color, title: title, body: body);
  }
}
