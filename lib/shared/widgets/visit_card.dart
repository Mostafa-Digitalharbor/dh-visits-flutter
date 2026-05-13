import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/utils/communications.dart';
import '../../core/utils/user_time.dart';
import '../../features/visits/data/models/visit.dart';
import '../extensions/context_extensions.dart';
import 'app_card.dart';

/// A polished card for displaying a visit in lists / detail pages.
///
/// Two visual variants:
/// - **Active** (visit.state == checkedIn): green accent, pulsing live dot,
///   "Running" indicator on the check-out side.
/// - **Completed** (visit.state == checkedOut): muted primary accent,
///   duration shown in the middle.
class VisitCard extends StatelessWidget {
  final Visit visit;
  final VoidCallback? onTap;
  final bool compact;

  /// Optional substring to highlight inside the customer name — used by
  /// the visits list when a search query is active.
  final String? highlight;

  /// Show the assigned employee's name as a small chip under the
  /// customer name. Admin views set this to true so the supervisor can
  /// scan "who's at which customer"; employees see their own name on
  /// every visit so we keep it off for them by default.
  final bool showEmployee;

  const VisitCard({
    super.key,
    required this.visit,
    this.onTap,
    this.compact = false,
    this.highlight,
    this.showEmployee = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isActive = visit.state == VisitStateType.checkedIn;
    final isCompleted = visit.state == VisitStateType.checkedOut;
    final accent = isActive
        ? Colors.green.shade600
        : (isCompleted ? colors.primary : colors.onSurfaceVariant);

    final timeFmt = DateFormat('HH:mm');
    final dateFmt = DateFormat('yyyy-MM-dd');

    final card = AppCard(
      onTap: onTap,
      padding: EdgeInsets.fromLTRB(14, 12, 14, compact ? 10 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top: lifecycle state + (optional overdue + active) + date
          Row(
            children: [
              _LifecycleBadge(state: visit.lifecycleState),
              if (isActive) ...[
                const SizedBox(width: 6),
                _LiveBadge(accent: accent),
              ],
              if (!isActive && !isCompleted && visit.isOverdue) ...[
                const SizedBox(width: 6),
                _StatusChip(
                  label: context.s.visitsHistoryOverdueBadge,
                  color: Colors.red.shade600,
                  icon: Icons.warning_amber_rounded,
                ),
              ],
              const Spacer(),
              if (visit.checkInTime != null)
                Text(
                  dateFmt.format(context.toUserTime(visit.checkInTime!)),
                  style: context.text.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Visit ref + customer row
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.primary,
                      Color.lerp(colors.primary, colors.tertiary, 0.55) ??
                          colors.primary,
                    ],
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.business_rounded,
                  size: 18,
                  color: colors.onPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visit.name ?? '#${visit.id}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (visit.customerName != null)
                      _HighlightedText(
                        text: visit.customerName!,
                        highlight: highlight,
                        baseStyle: context.text.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                        highlightStyle: context.text.bodySmall?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                          backgroundColor:
                              colors.primary.withValues(alpha: 0.10),
                        ),
                      ),
                    if (showEmployee && visit.employeeName != null) ...[
                      const SizedBox(height: 4),
                      _EmployeeChip(name: visit.employeeName!),
                    ],
                  ],
                ),
              ),
              // Compact visit-type chip on the trailing edge of the
              // customer row — keeps the badge near the customer name
              // so the admin scans (customer + type) together.
              if (visit.visitTypeName != null) ...[
                const SizedBox(width: 6),
                _VisitTypePill(name: visit.visitTypeName!),
              ],
            ],
          ),

          if (!compact) ...[
            const SizedBox(height: 14),
            _Timeline(
              checkIn: visit.checkInTime != null
                  ? timeFmt.format(context.toUserTime(visit.checkInTime!))
                  : '—',
              checkOut: visit.checkOutTime != null
                  ? timeFmt.format(context.toUserTime(visit.checkOutTime!))
                  : null,
              isActive: isActive,
              duration: visit.visitDuration,
              accent: accent,
            ),
            if (_executionHint(context, visit) != null) ...[
              const SizedBox(height: 8),
              _ExecutionDeltaPill(visit: visit),
            ],
            const SizedBox(height: 10),
            Divider(height: 1, color: colors.outlineVariant),
            const SizedBox(height: 4),
            _LocationButton(visit: visit),
          ],
        ],
      ),
    );

    // Wrap active visits in a soft green halo so they pop out of the
    // list at a glance, with a slow pulse to draw the eye.
    if (!isActive) return card;
    return _ActiveGlow(accent: accent, child: card);
  }
}

/// Single-line text that highlights all case-insensitive occurrences of
/// `highlight` inside `text`. Falls back to a plain `Text` when there's
/// nothing to highlight so the common path stays cheap.
class _HighlightedText extends StatelessWidget {
  final String text;
  final String? highlight;
  final TextStyle? baseStyle;
  final TextStyle? highlightStyle;

  const _HighlightedText({
    required this.text,
    required this.highlight,
    required this.baseStyle,
    required this.highlightStyle,
  });

  @override
  Widget build(BuildContext context) {
    final q = highlight?.trim() ?? '';
    if (q.isEmpty) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: baseStyle,
      );
    }
    final lowerText = text.toLowerCase();
    final lowerQuery = q.toLowerCase();
    final spans = <TextSpan>[];
    var i = 0;
    while (i < text.length) {
      final hit = lowerText.indexOf(lowerQuery, i);
      if (hit < 0) {
        spans.add(TextSpan(text: text.substring(i), style: baseStyle));
        break;
      }
      if (hit > i) {
        spans.add(TextSpan(text: text.substring(i, hit), style: baseStyle));
      }
      spans.add(TextSpan(
        text: text.substring(hit, hit + q.length),
        style: highlightStyle,
      ));
      i = hit + q.length;
    }
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(children: spans),
    );
  }
}

/// Returns the localised execution-delta line for a visit, or `null`
/// when nothing useful to say (visit unfinished, or no schedule info).
String? _executionHint(BuildContext context, Visit v) {
  final delta = v.executionDaysDelta;
  if (delta == null) return null;
  if (delta == 0) return context.s.visitExecutedOnTime;
  final abs = delta.abs();
  return delta < 0
      ? context.s.visitExecutedEarly(abs)
      : context.s.visitExecutedLate(abs);
}

/// Thin info pill placed under the timeline when the visit ran on a
/// different day than originally scheduled. Color-codes by direction
/// (early = green, late = amber, on-time = primary muted) so the admin
/// can scan a long list and spot schedule slippage.
class _ExecutionDeltaPill extends StatelessWidget {
  final Visit visit;
  const _ExecutionDeltaPill({required this.visit});

  @override
  Widget build(BuildContext context) {
    final delta = visit.executionDaysDelta;
    if (delta == null) return const SizedBox.shrink();
    final colors = context.colors;
    final (color, icon) = switch (delta.compareTo(0)) {
      < 0 => (Colors.green.shade600, Icons.fast_rewind_rounded),
      > 0 => (Colors.amber.shade700, Icons.fast_forward_rounded),
      _ => (colors.onSurfaceVariant, Icons.check_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _executionHint(context, visit) ?? '',
              style: context.text.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pulsing green halo applied behind active (`checkedIn`) visit cards.
/// The shadow grows + shrinks gently so it reads as "alive" without
/// being noisy.
class _ActiveGlow extends StatefulWidget {
  final Color accent;
  final Widget child;
  const _ActiveGlow({required this.accent, required this.child});

  @override
  State<_ActiveGlow> createState() => _ActiveGlowState();
}

class _ActiveGlowState extends State<_ActiveGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, child) {
        final t = Curves.easeInOut.transform(_pulse.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: widget.accent.withValues(alpha: 0.18 + 0.18 * t),
                blurRadius: 14 + 10 * t,
                spreadRadius: 1 + 1.5 * t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _LocationButton extends StatelessWidget {
  final Visit visit;
  const _LocationButton({required this.visit});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = visit.hasCustomerLocation;
    return InkWell(
      onTap: enabled
          ? () => Communications.openInMaps(
                visit.customerLatitude!,
                visit.customerLongitude!,
                label: visit.customerName,
              )
          : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_rounded,
              size: 16,
              color: enabled ? colors.primary : colors.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              enabled
                  ? context.s.visitShowLocation
                  : context.s.visitLocationNotAvailable,
              style: context.text.labelLarge?.copyWith(
                color: enabled ? colors.primary : colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveBadge extends StatefulWidget {
  final Color accent;
  const _LiveBadge({required this.accent});

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: widget.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.accent,
                boxShadow: [
                  BoxShadow(
                    color:
                        widget.accent.withValues(alpha: 0.5 + _pulse.value * 0.5),
                    blurRadius: 2 + _pulse.value * 8,
                    spreadRadius: _pulse.value * 1.5,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            context.s.visitsHistoryActiveBadge,
            style: TextStyle(
              color: widget.accent,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// Primary status pill on the visit card — maps Odoo's lifecycle to
/// the three labels the admin asked for (Draft / Submit / Done) with
/// distinct colors so the list is easy to skim. Unknown and cancel
/// states render as a muted grey chip.
/// Small label-pill that surfaces the `customer.visit.type` name on
/// the card (e.g. تحصيل / ديمو / تدريب). Tertiary-tinted so it doesn't
/// fight the lifecycle badge at the top of the card for attention.
/// Compact "assigned to" chip — small avatar circle with the
/// salesperson's initial + their name. Sits under the customer name on
/// admin-side cards so the supervisor can scan responsibility without
/// opening the visit.
class _EmployeeChip extends StatelessWidget {
  final String name;
  const _EmployeeChip({required this.name});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final initial =
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.tertiaryContainer,
          ),
          child: Text(
            initial,
            style: TextStyle(
              color: colors.onTertiaryContainer,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _VisitTypePill extends StatelessWidget {
  final String name;
  const _VisitTypePill({required this.name});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.tertiary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.tertiary.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.label_outline_rounded,
              size: 12, color: colors.tertiary),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 90),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.tertiary,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LifecycleBadge extends StatelessWidget {
  final VisitLifecycleState state;
  const _LifecycleBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Four distinct buckets — admins need to spot Under Review as its
    // own thing (work done but waiting on review) instead of merging
    // it with Submit.
    final (label, color, icon) = switch (state) {
      VisitLifecycleState.draft => (
        context.s.visitStateDraft,
        colors.onSurfaceVariant,
        Icons.edit_note_rounded,
      ),
      VisitLifecycleState.submit => (
        context.s.visitStateSubmit,
        colors.primary,
        Icons.play_arrow_rounded,
      ),
      VisitLifecycleState.underReview => (
        context.s.visitStateUnderReview,
        Colors.amber.shade700,
        Icons.rate_review_rounded,
      ),
      VisitLifecycleState.done => (
        context.s.visitStateDone,
        Colors.green.shade600,
        Icons.check_circle_rounded,
      ),
      VisitLifecycleState.cancel => (
        context.s.visitStateCancel,
        Colors.red.shade600,
        Icons.cancel_rounded,
      ),
      VisitLifecycleState.unknown => (
        context.s.visitsHistoryIncompleteBadge,
        colors.onSurfaceVariant,
        Icons.help_outline_rounded,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _StatusChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  final String checkIn;
  final String? checkOut;
  final bool isActive;
  final Duration? duration;
  final Color accent;

  const _Timeline({
    required this.checkIn,
    required this.checkOut,
    required this.isActive,
    required this.duration,
    required this.accent,
  });

  /// Formats `duration` as `HH:MM:SS` so even sub-minute visits read
  /// `00:00:33` instead of "0 min".
  static String _format(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final checkInEndpoint = _TimelineEndpoint(
      label: context.s.timelineCheckIn,
      time: checkIn,
      icon: Icons.login_rounded,
      color: accent,
    );
    final checkOutEndpoint = _TimelineEndpoint(
      label: context.s.timelineCheckOut,
      time: checkOut ?? '—',
      icon: Icons.logout_rounded,
      color: isActive ? colors.onSurfaceVariant : accent,
      muted: isActive,
    );
    final connector = Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            CustomPaint(
              size: const Size(double.infinity, 12),
              painter: _DashedLinePainter(
                color: colors.outlineVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isActive
                  ? context.s.visitsHistoryRunning
                  : (duration != null ? _format(duration!) : '-'),
              style: context.text.labelSmall?.copyWith(
                color: isActive ? accent : colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );

    // Reading order:
    //  - Arabic (RTL): right-to-left, so check-out is on the right
    //    (visually first) and check-in is on the left.
    //  - English (LTR): left-to-right, so check-in is on the left
    //    (visually first) and check-out is on the right.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: context.isRtl
          ? [checkOutEndpoint, connector, checkInEndpoint]
          : [checkInEndpoint, connector, checkOutEndpoint],
    );
  }
}

class _TimelineEndpoint extends StatelessWidget {
  final String label;
  final String time;
  final IconData icon;
  final Color color;
  final bool muted;

  const _TimelineEndpoint({
    required this.label,
    required this.time,
    required this.icon,
    required this.color,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: muted
                ? colors.surfaceContainerHighest
                : color.withValues(alpha: 0.15),
            border: Border.all(
              color: muted ? colors.outlineVariant : color,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 14, color: muted ? colors.onSurfaceVariant : color),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: context.text.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          time,
          style: context.text.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: muted ? colors.onSurfaceVariant : colors.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double startX = 0;
    final y = size.height / 2;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, y), Offset(startX + dashWidth, y), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
