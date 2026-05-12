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

  const VisitCard({
    super.key,
    required this.visit,
    this.onTap,
    this.compact = false,
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

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.fromLTRB(14, 12, 14, compact ? 10 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top: status badge + date
          Row(
            children: [
              if (isActive)
                _LiveBadge(accent: accent)
              else if (isCompleted)
                _StatusChip(
                  label: context.s.visitsHistoryCompletedBadge,
                  color: colors.primary,
                  icon: Icons.check_circle_rounded,
                )
              else
                _StatusChip(
                  label: context.s.visitsHistoryIncompleteBadge,
                  color: colors.onSurfaceVariant,
                  icon: Icons.schedule_rounded,
                ),
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
                      Text(
                        visit.customerName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
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
              durationMinutes: visit.durationMinutes,
              accent: accent,
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: colors.outlineVariant),
            const SizedBox(height: 4),
            _LocationButton(visit: visit),
          ],
        ],
      ),
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
  final int? durationMinutes;
  final Color accent;

  const _Timeline({
    required this.checkIn,
    required this.checkOut,
    required this.isActive,
    required this.durationMinutes,
    required this.accent,
  });

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
                  : (durationMinutes != null
                      ? context.s.timelineDuration(durationMinutes.toString())
                      : '-'),
              style: context.text.labelSmall?.copyWith(
                color: isActive ? accent : colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
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
