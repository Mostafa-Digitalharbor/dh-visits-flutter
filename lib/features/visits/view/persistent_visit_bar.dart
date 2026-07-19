import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/extensions/context_extensions.dart';
import '../bloc/visit_bloc.dart';
import '../../../core/utils/duration_format.dart';

/// Slim banner that lives just above the bottom navigation while a visit is
/// active. Shows the running timer + customer name + a quick check-out
/// button. Tapping the bar (anywhere outside the action) switches to the
/// Active tab.
///
/// Auto-hides (animates out) when there is no active visit.
class PersistentVisitBar extends StatelessWidget {
  /// Called when the user taps the body of the bar to jump to the active
  /// visit tab.
  final VoidCallback onTap;

  const PersistentVisitBar({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VisitBloc, VisitState>(
      buildWhen: (prev, curr) =>
          prev.status != curr.status ||
          prev.activeVisit?.id != curr.activeVisit?.id,
      builder: (context, state) {
        final visit = state.activeVisit;
        final showing = state.status == VisitStatus.running &&
            visit != null &&
            visit.startDatetime != null;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: animation,
            axisAlignment: 1,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: showing
              ? _BarContent(
                  key: ValueKey(visit.id),
                  visit: visit,
                  onTap: onTap,
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }
}

class _BarContent extends StatefulWidget {
  final dynamic visit; // Visit — typed via state above
  final VoidCallback onTap;

  const _BarContent({super.key, required this.visit, required this.onTap});

  @override
  State<_BarContent> createState() => _BarContentState();
}

class _BarContentState extends State<_BarContent>
    with SingleTickerProviderStateMixin {
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _refresh();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(_refresh);
    });
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  void _refresh() {
    final start = widget.visit.checkInTime as DateTime?;
    if (start != null) {
      _elapsed = DateTime.now().difference(start);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = Colors.green.shade600;
    final visit = widget.visit;
    return Material(
      color: colors.surface,
      elevation: 6,
      child: SafeArea(
        top: false,
        child: InkWell(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
                vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: colors.outlineVariant),
                bottom: BorderSide(color: colors.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                // Pulsing live indicator
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent,
                      boxShadow: [
                        BoxShadow(
                          color:
                              accent.withValues(alpha: 0.4 + _pulse.value * 0.5),
                          blurRadius: 4 + _pulse.value * 10,
                          spreadRadius: _pulse.value * 1.5,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Timer + customer name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _elapsed.clockWithSeconds,
                        style: context.text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: accent,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          height: 1.1,
                        ),
                      ),
                      if (visit.customerName != null)
                        Text(
                          visit.customerName as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.1,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  context.isRtl
                      ? Icons.chevron_left
                      : Icons.chevron_right,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
