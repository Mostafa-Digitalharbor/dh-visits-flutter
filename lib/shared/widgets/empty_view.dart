import 'package:flutter/material.dart';

import '../extensions/context_extensions.dart';

class EmptyView extends StatelessWidget {
  final String message;
  final IconData icon;
  final Widget? action;

  const EmptyView({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Decorative icon with halo
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors.primaryContainer.withValues(alpha: 0.45),
                    colors.primaryContainer.withValues(alpha: 0.0),
                  ],
                ),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.surfaceContainerHighest,
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Icon(icon, size: 34, color: colors.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.text.bodyLarge?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
