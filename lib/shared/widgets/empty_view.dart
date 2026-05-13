import 'package:flutter/material.dart';

import '../extensions/context_extensions.dart';

class EmptyView extends StatefulWidget {
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
  State<EmptyView> createState() => _EmptyViewState();
}

class _EmptyViewState extends State<EmptyView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Brand-tinted icon with a softly pulsing halo.
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) {
                final t = Curves.easeInOut.transform(_pulse.value);
                return Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color.lerp(
                                colors.primary, colors.tertiary, 0.5)!
                            .withValues(alpha: 0.22 + 0.10 * t),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: child,
                );
              },
              child: Center(
                child: Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.surfaceContainerHighest,
                        colors.surfaceContainerHigh,
                      ],
                    ),
                    border: Border.all(
                      color: colors.outlineVariant,
                      width: 1,
                    ),
                  ),
                  child: Icon(widget.icon,
                      size: 36, color: colors.primary),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: context.text.bodyLarge?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (widget.action != null) ...[
              const SizedBox(height: 20),
              widget.action!,
            ],
          ],
        ),
      ),
    );
  }
}
