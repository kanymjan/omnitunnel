import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Назад по стеку; если стека нет (открыто по ссылке) — на [fallback].
void goBack(BuildContext context, String fallback) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}
