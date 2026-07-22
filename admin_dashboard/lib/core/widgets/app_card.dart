import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

const _cardRadius = BorderRadius.all(Radius.circular(AppRadius.lg));

/// Themed card with a sane default padding - CardTheme (app_theme.dart)
/// handles color/border/radius, this just saves every call site from
/// repeating the same Padding-wrapped-Card boilerplate.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) {
      return card;
    }

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: _cardRadius,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
