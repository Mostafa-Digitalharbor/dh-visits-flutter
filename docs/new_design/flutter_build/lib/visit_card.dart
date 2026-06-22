// // visit_card.dart — the hero list item. Role-aware. Mirrors components/visits/VisitCard.jsx 1:1.
// // See 02-components.md §7 and screenshots 04 (manager) / 10 (employee).
// import 'package:flutter/material.dart';
// import 'package:material_symbols_icons/symbols.dart';
// import 'app_dimens.dart';
// import 'app_theme.dart';

// enum VisitStatus { scheduled, active, review, approved, rejected }
// enum AppRole { manager, employee }

// class _StatusMeta { final String ar; final Color tone; final IconData? icon; final bool dot;
//   const _StatusMeta(this.ar, this.tone, {this.icon, this.dot = false}); }

// class VisitCard extends StatefulWidget {
//   final String id, customer, employee, employeeInitial, date, type;
//   final VisitStatus status;
//   final String? scheduledAt, arrival, departure;
//   final int? distance;            // manager + active only
//   final bool flagged;
//   final AppRole role;
//   final VoidCallback? onTap;
//   const VisitCard({super.key, required this.id, required this.customer, required this.employee,
//     required this.employeeInitial, required this.date, required this.type, required this.status,
//     this.scheduledAt, this.arrival, this.departure, this.distance, this.flagged = false,
//     required this.role, this.onTap});

//   @override State<VisitCard> createState() => _VisitCardState();
// }

// class _VisitCardState extends State<VisitCard> {
//   bool _hover = false;

//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     final x = Theme.of(context).extension<AppX>()!;
//     final rtl = Directionality.of(context) == TextDirection.rtl;

//     final meta = {
//       VisitStatus.scheduled: _StatusMeta('مجدولة', cs.primary, icon: Symbols.schedule),
//       VisitStatus.active:    _StatusMeta('نشطة الآن', x.success, dot: true),
//       VisitStatus.review:    _StatusMeta('بانتظار المراجعة', x.warning, icon: Symbols.pending),
//       VisitStatus.approved:  _StatusMeta('معتمدة', x.info, icon: Symbols.verified),
//       VisitStatus.rejected:  _StatusMeta('مرفوضة', cs.error, icon: Symbols.cancel),
//     }[widget.status]!;
//     final active = widget.status == VisitStatus.active;

//     return MouseRegion(
//       onEnter: (_) => setState(() => _hover = true),
//       onExit: (_) => setState(() => _hover = false),
//       child: GestureDetector(
//         onTap: widget.onTap,
//         child: AnimatedContainer(
//           duration: Durations.base,
//           transform: Matrix4.translationValues(0, _hover ? -1 : 0, 0),
//           padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 16, 14),
//           decoration: BoxDecoration(
//             color: cs.surfaceContainerLowest,
//             borderRadius: BorderRadius.circular(Radii.lg),
//             border: Border.all(color: active ? x.success.withOpacity(.32) : x.outlineVariant),
//             boxShadow: active ? [...x.glowSuccess, ...x.elev1] : (_hover ? x.elev2 : x.elev1),
//           ),
//           child: Stack(children: [
//             // status accent rail (inline-start)
//             PositionedDirectional(start: -18, top: -14, bottom: -14,
//               child: Container(width: 4, color: meta.tone)),
//             Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
//               _identityRow(cs, x, meta, active),
//               const SizedBox(height: 13),
//               widget.role == AppRole.manager ? _assigneeRow(cs, x) : _affordanceRow(x),
//               const SizedBox(height: 13),
//               _timesStrip(cs, x, rtl),
//             ]),
//           ]),
//         ),
//       ),
//     );
//   }

//   Widget _identityRow(ColorScheme cs, AppX x, _StatusMeta meta, bool active) => Row(children: [
//     Stack(clipBehavior: Clip.none, children: [
//       Container(width: 46, height: 46,
//         decoration: BoxDecoration(gradient: x.avatarGradient, borderRadius: BorderRadius.circular(14), boxShadow: x.elev1),
//         child: const Icon(Symbols.business, fill: 1, size: 24, color: Colors.white)),
//       if (active) PositionedDirectional(end: -3, top: -3, child: Container(width: 14, height: 14,
//         decoration: BoxDecoration(color: x.success, shape: BoxShape.circle,
//           border: Border.all(color: cs.surfaceContainerLowest, width: 2)))),
//     ]),
//     const SizedBox(width: 12),
//     Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
//       Text(widget.customer, maxLines: 1, overflow: TextOverflow.ellipsis,
//         style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: cs.onSurface)),
//       const SizedBox(height: 2),
//       Row(children: [
//         Text(widget.id, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: x.textTertiary)),
//         const SizedBox(width: 7), Container(width: 3, height: 3, decoration: BoxDecoration(color: cs.outline, shape: BoxShape.circle)),
//         const SizedBox(width: 7),
//         Text(widget.type, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: x.accentHover)),
//       ]),
//     ])),
//     const SizedBox(width: 8),
//     _badge(meta.ar, meta.tone, icon: meta.icon, dot: meta.dot),
//   ]);

//   Widget _assigneeRow(ColorScheme cs, AppX x) => Container(
//     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//     decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(Radii.sm)),
//     child: Row(children: [
//       Container(width: 26, height: 26, alignment: Alignment.center,
//         decoration: BoxDecoration(color: cs.tertiaryContainer, shape: BoxShape.circle),
//         child: Text(widget.employeeInitial, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: x.accentHover))),
//       const SizedBox(width: 9),
//       Text(widget.employee, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
//       const Spacer(),
//       if (widget.distance != null) Row(children: [
//         Icon(Symbols.near_me, size: 15, color: x.textTertiary),
//         const SizedBox(width: 4),
//         Text('${widget.distance} م', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: x.textTertiary)),
//       ]),
//     ]),
//   );

//   Widget _affordanceRow(AppX x) {
//     final cs = Theme.of(context).colorScheme;
//     final map = {
//       VisitStatus.scheduled: [Symbols.touch_app, cs.primary, 'اضغط لبدء الزيارة'],
//       VisitStatus.active:    [Symbols.bolt, x.success, 'زيارة جارية الآن'],
//       VisitStatus.review:    [Symbols.hourglass_top, x.warning, 'بانتظار مراجعة المدير'],
//       VisitStatus.approved:  [Symbols.verified, x.success, 'تم اعتمادها'],
//       VisitStatus.rejected:  [Symbols.replay, cs.error, 'مرفوضة — أعد الزيارة'],
//     }[widget.status]!;
//     return Row(children: [
//       Icon(map[0] as IconData, fill: 1, size: 18, color: map[1] as Color),
//       const SizedBox(width: 8),
//       Text(map[2] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: map[1] as Color)),
//     ]);
//   }

//   Widget _timesStrip(ColorScheme cs, AppX x, bool rtl) {
//     Widget chip(IconData i, String label, String? time, Color tone) => Row(mainAxisSize: MainAxisSize.min, children: [
//       Icon(i, size: 16, color: time != null ? tone : x.textDisabled),
//       const SizedBox(width: 6),
//       Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: x.textTertiary)),
//       const SizedBox(width: 4),
//       Text(time ?? '—:—', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
//         color: time != null ? cs.onSurface : x.textDisabled, fontFeatures: const [FontFeature.tabularFigures()])),
//     ]);
//     return Container(
//       padding: const EdgeInsets.only(top: 12),
//       decoration: BoxDecoration(border: Border(top: BorderSide(color: x.divider))),
//       child: Row(children: [
//         if (widget.status == VisitStatus.scheduled)
//           chip(Symbols.event, 'الموعد', widget.scheduledAt, cs.primary)
//         else ...[
//           chip(Symbols.login, 'بدء', widget.arrival, x.success),
//           const SizedBox(width: 10), Icon(Symbols.arrow_back, size: 16, color: cs.outline), const SizedBox(width: 10),
//           chip(Symbols.logout, 'إنهاء', widget.departure, cs.error),
//         ],
//         const Spacer(),
//         Text(widget.date, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: x.textTertiary)),
//         Icon(rtl ? Symbols.chevron_left : Symbols.chevron_right, size: 18, color: x.textDisabled),
//       ]),
//     );
//   }

//   Widget _badge(String label, Color tone, {IconData? icon, bool dot = false}) {
//     Color container = tone.withOpacity(.14);
//     return Container(
//       height: 26, padding: const EdgeInsets.symmetric(horizontal: 11),
//       decoration: BoxDecoration(color: container, borderRadius: BorderRadius.circular(999)),
//       child: Row(mainAxisSize: MainAxisSize.min, children: [
//         if (dot) Padding(padding: const EdgeInsetsDirectional.only(end: 6),
//           child: Container(width: 8, height: 8, decoration: BoxDecoration(color: tone, shape: BoxShape.circle))),
//         if (icon != null) Padding(padding: const EdgeInsetsDirectional.only(end: 5), child: Icon(icon, fill: 1, size: 15, color: tone)),
//         Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tone)),
//       ]),
//     );
//   }
// }
