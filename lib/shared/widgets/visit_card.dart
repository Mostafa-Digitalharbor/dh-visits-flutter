import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/theme.dart';
import '../../core/utils/user_time.dart';
import '../../features/visits/data/models/visit.dart';
import '../extensions/context_extensions.dart';

/// The hero list item — role-aware visit card. Matches the design package
/// `02-components.md §7` + screenshots 04 (manager) / 10 (employee), adapted
/// onto the real [Visit] model.
class VisitCard extends StatelessWidget {
  final Visit visit;
  final VoidCallback? onTap;
  final bool compact;

  /// Optional substring to highlight inside the customer name (search).
  final String? highlight;

  /// Manager view → shows the assignee strip; employee view → shows the
  /// status affordance line.
  final bool showEmployee;

  const VisitCard({
    super.key,
    required this.visit,
    this.onTap,
    this.compact = false,
    this.highlight,
    this.showEmployee = false,
  });

  /// Maps the real [Visit] lifecycle/state onto the design's 5 visual statuses.
  _CardStatus get _status {
    if (visit.state == VisitStateType.checkedIn) return _CardStatus.active;
    switch (visit.lifecycleState) {
      case VisitLifecycleState.done:
        return _CardStatus.approved;
      case VisitLifecycleState.underReview:
        return _CardStatus.review;
      case VisitLifecycleState.cancel:
        return _CardStatus.rejected;
      case VisitLifecycleState.draft:
      case VisitLifecycleState.submit:
      case VisitLifecycleState.unknown:
        if (visit.state == VisitStateType.checkedOut) return _CardStatus.review;
        return _CardStatus.scheduled;
    }
  }

  bool get _flagged =>
      visit.checkInState == VisitRangeState.notInRange ||
      visit.checkOutState == VisitRangeState.notInRange;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final x = context.x;
    final rtl = context.isRtl;
    final status = _status;
    final meta = _statusMeta(context, status);
    final active = status == _CardStatus.active;

    final timeFmt = DateFormat('HH:mm');
    final dateFmt = DateFormat('yyyy-MM-dd');
    final arrival =
        visit.checkInTime != null ? timeFmt.format(context.toUserTime(visit.checkInTime!)) : null;
    final departure =
        visit.checkOutTime != null ? timeFmt.format(context.toUserTime(visit.checkOutTime!)) : null;
    final scheduledAt = visit.visitDate != null ? timeFmt.format(visit.visitDate!) : null;
    final dateText = (visit.effectiveDate != null)
        ? dateFmt.format(visit.effectiveDate!.isUtc
            ? context.toUserTime(visit.effectiveDate!)
            : visit.effectiveDate!)
        : '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 16, 14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(
            color: active ? x.success.withValues(alpha: 0.32) : x.outlineVariant,
          ),
          boxShadow: active ? [...x.glowSuccess, ...x.elev1] : x.elev1,
        ),
        child: ClipRect(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Status accent rail (inline-start, full height).
              PositionedDirectional(
                start: -18,
                top: -14,
                bottom: -14,
                child: Container(width: 4, color: meta.tone),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _identityRow(context, cs, x, meta, active),
                  const SizedBox(height: 13),
                  showEmployee ? _assigneeRow(context, cs, x) : _affordanceRow(context, x, status),
                  if (!compact) ...[
                    const SizedBox(height: 13),
                    _timesStrip(context, cs, x, rtl, status, scheduledAt, arrival, departure, dateText),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _identityRow(
      BuildContext context, ColorScheme cs, AppX x, _StatusMeta meta, bool active) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: x.avatarGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: x.elev1,
              ),
              child: const Icon(Symbols.business, fill: 1, size: 24, color: Colors.white),
            ),
            if (active)
              PositionedDirectional(
                end: -3,
                top: -3,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: x.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.surfaceContainerLowest, width: 2),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _HighlightedText(
                text: visit.customerName ?? (visit.name ?? '#${visit.id}'),
                highlight: highlight,
                base: AppType.cardTitle.copyWith(color: cs.onSurface),
                hi: AppType.cardTitle.copyWith(color: cs.primary),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      visit.name ?? '#${visit.id}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600, color: x.textTertiary),
                    ),
                  ),
                  if (visit.visitTypeName != null) ...[
                    const SizedBox(width: 7),
                    Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(color: cs.outline, shape: BoxShape.circle)),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        visit.visitTypeName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700, color: x.accentHover),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _badge(meta.ar, meta.tone, icon: meta.icon, dot: meta.dot),
            if (_flagged) ...[
              const SizedBox(height: 6),
              _badge(context.s.visitRangeOutOfRange, cs.error, icon: Symbols.warning),
            ],
          ],
        ),
      ],
    );
  }

  Widget _assigneeRow(BuildContext context, ColorScheme cs, AppX x) {
    final name = visit.employeeName ?? '-';
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: cs.tertiaryContainer, shape: BoxShape.circle),
            child: Text(initial,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: x.accentHover)),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  Widget _affordanceRow(BuildContext context, AppX x, _CardStatus status) {
    final cs = context.colors;
    final (IconData icon, Color tone, String label) = switch (status) {
      _CardStatus.scheduled => (Symbols.touch_app, cs.primary, context.s.affordanceScheduled),
      _CardStatus.active => (Symbols.bolt, x.success, context.s.affordanceActive),
      _CardStatus.review => (Symbols.hourglass_top, x.warning, context.s.affordanceReview),
      _CardStatus.approved => (Symbols.verified, x.success, context.s.affordanceApproved),
      _CardStatus.rejected => (Symbols.replay, cs.error, context.s.affordanceRejected),
    };
    return Row(
      children: [
        Icon(icon, fill: 1, size: 18, color: tone),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tone)),
        ),
      ],
    );
  }

  Widget _timesStrip(BuildContext context, ColorScheme cs, AppX x, bool rtl, _CardStatus status,
      String? scheduledAt, String? arrival, String? departure, String dateText) {
    Widget chip(IconData i, String label, String? time, Color tone) =>
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, size: 16, color: time != null ? tone : x.textDisabled),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: x.textTertiary)),
          const SizedBox(width: 4),
          Text(time ?? '—:—',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: time != null ? cs.onSurface : x.textDisabled,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ]);
    return Container(
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: x.divider))),
      child: Row(
        children: [
          if (status == _CardStatus.scheduled)
            chip(Symbols.event, context.s.visitsScheduledLabel, scheduledAt, cs.primary)
          else ...[
            chip(Symbols.login, context.s.timelineCheckIn, arrival, x.success),
            const SizedBox(width: 10),
            Icon(rtl ? Symbols.arrow_back : Symbols.arrow_forward, size: 16, color: cs.outline),
            const SizedBox(width: 10),
            chip(Symbols.logout, context.s.timelineCheckOut, departure, cs.error),
          ],
          const Spacer(),
          Text(dateText,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: x.textTertiary)),
          Icon(rtl ? Symbols.chevron_left : Symbols.chevron_right, size: 18, color: x.textDisabled),
        ],
      ),
    );
  }

  Widget _badge(String label, Color tone, {IconData? icon, bool dot = false}) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 6),
              child: Container(
                  width: 8, height: 8, decoration: BoxDecoration(color: tone, shape: BoxShape.circle)),
            ),
          if (icon != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 5),
              child: Icon(icon, fill: 1, size: 15, color: tone),
            ),
          Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tone)),
        ],
      ),
    );
  }

  _StatusMeta _statusMeta(BuildContext context, _CardStatus status) {
    final cs = context.colors;
    final x = context.x;
    return switch (status) {
      _CardStatus.scheduled =>
        _StatusMeta(context.s.visitStateSubmit, cs.primary, icon: Symbols.schedule),
      _CardStatus.active => _StatusMeta(context.s.visitsHistoryActiveBadge, x.success, dot: true),
      _CardStatus.review =>
        _StatusMeta(context.s.visitStateUnderReview, x.warning, icon: Symbols.pending),
      _CardStatus.approved =>
        _StatusMeta(context.s.visitStateDone, x.info, icon: Symbols.verified),
      _CardStatus.rejected =>
        _StatusMeta(context.s.visitStateCancel, cs.error, icon: Symbols.cancel),
    };
  }
}

enum _CardStatus { scheduled, active, review, approved, rejected }

class _StatusMeta {
  final String ar;
  final Color tone;
  final IconData? icon;
  final bool dot;
  const _StatusMeta(this.ar, this.tone, {this.icon, this.dot = false});
}

/// Single-line text that highlights case-insensitive occurrences of [highlight].
class _HighlightedText extends StatelessWidget {
  final String text;
  final String? highlight;
  final TextStyle base;
  final TextStyle hi;
  const _HighlightedText(
      {required this.text, required this.highlight, required this.base, required this.hi});

  @override
  Widget build(BuildContext context) {
    final q = highlight?.trim() ?? '';
    if (q.isEmpty) {
      return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: base);
    }
    final lower = text.toLowerCase();
    final lq = q.toLowerCase();
    final spans = <TextSpan>[];
    var i = 0;
    while (i < text.length) {
      final hit = lower.indexOf(lq, i);
      if (hit < 0) {
        spans.add(TextSpan(text: text.substring(i), style: base));
        break;
      }
      if (hit > i) spans.add(TextSpan(text: text.substring(i, hit), style: base));
      spans.add(TextSpan(text: text.substring(hit, hit + q.length), style: hi));
      i = hit + q.length;
    }
    return RichText(
        maxLines: 1, overflow: TextOverflow.ellipsis, text: TextSpan(children: spans));
  }
}
