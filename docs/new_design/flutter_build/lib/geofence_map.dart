// // geofence_map.dart
// // ============================================================================
// // The live GPS / geofence map used on the Visit-detail screen.
// //
// // This is a 1:1 Flutter port of the web prototype's `MapView` (see
// // ui_kits/customer-visits/VisitDetailScreen.jsx). It renders:
// //   • a static map image (assets/images/map-cairo.png) with a readability veil
// //   • the customer geofence  — a dashed translucent green circle
// //   • TWO expanding pulse rings around the employee's live GPS dot
// //   • a "breathing" centre dot
// //   • a radar sweep over the geofence while the app is acquiring a fix
// //   • the customer pin (gradient teardrop) + the GPS dot
// //   • floating chrome (live-tracking pill, directions FAB)
// //
// // All geometry is expressed the same way as the web version: each point is an
// // (x%, y%) offset over the map box, so the layout is resolution-independent.
// //
// // Pure Flutter — no map SDK. Drop a real `google_maps_flutter`/`mapbox` widget
// // in place of the AssetImage later; the painter layers stay identical.
// // ============================================================================

// import 'dart:math' as math;
// import 'package:flutter/material.dart';
// import 'package:material_symbols_icons/symbols.dart';
// import 'app_theme.dart'; // AppX extension (success, accent, gradients, elevations)

// /// A point placed as a fraction (0..1) of the map box. `x` is the inline axis,
// /// `y` the block axis — matches the prototype's `{x: 50, y: 46}` (in %, ÷100).
// class MapPoint {
//   final double x, y;
//   const MapPoint(this.x, this.y);
//   Alignment toAlignment() => Alignment(x * 2 - 1, y * 2 - 1); // 0..1 → -1..1
// }

// enum VisitPhase { scheduled, locatingIn, active, locatingOut, completed }

// class GeofenceMap extends StatefulWidget {
//   final MapPoint customer; // geofence centre + pin
//   final MapPoint me; // live GPS dot
//   final VisitPhase phase; // drives the radar sweep
//   final double height;
//   final String liveTrackingLabel; // "تتبّع مباشر"
//   final ImageProvider mapImage;
//   final VoidCallback? onDirections;

//   const GeofenceMap({
//     super.key,
//     required this.customer,
//     required this.me,
//     required this.phase,
//     required this.mapImage,
//     this.height = 300,
//     this.liveTrackingLabel = 'تتبّع مباشر',
//     this.onDirections,
//   });

//   @override
//   State<GeofenceMap> createState() => _GeofenceMapState();
// }

// class _GeofenceMapState extends State<GeofenceMap> with TickerProviderStateMixin {
//   // One 2s controller drives BOTH pulse rings + the breathing dot (their phases
//   // are offset in the painter). A separate 1.4s controller drives the sweep.
//   late final AnimationController _pulse =
//       AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
//   late final AnimationController _sweep =
//       AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

//   bool get _locating =>
//       widget.phase == VisitPhase.locatingIn || widget.phase == VisitPhase.locatingOut;

//   @override
//   void dispose() {
//     _pulse.dispose();
//     _sweep.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     final x = Theme.of(context).extension<AppX>()!;

//     return SizedBox(
//       height: widget.height,
//       child: ClipRect(
//         child: Stack(
//           fit: StackFit.expand,
//           children: [
//             // 1) base map (swap for a real map widget later) + dark-mode tint
//             ColorFiltered(
//               colorFilter: x.isDark
//                   ? const ColorFilter.matrix(_kDarkMapMatrix)
//                   : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
//               child: Image(image: widget.mapImage, fit: BoxFit.cover),
//             ),

//             // 2) readability veil (top + bottom gradient)
//             const DecoratedBox(
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   begin: Alignment.topCenter,
//                   end: Alignment.bottomCenter,
//                   stops: [0, .26, .64, 1],
//                   colors: [
//                     Color(0x470A0B0F), // .28
//                     Color(0x000A0B0F),
//                     Color(0x000A0B0F),
//                     Color(0x570A0B0F), // .34
//                   ],
//                 ),
//               ),
//             ),

//             // 3) animated geofence + pulse rings + sweep (all in one painter,
//             //    so they stay perfectly registered to the same centre points)
//             AnimatedBuilder(
//               animation: Listenable.merge([_pulse, _sweep]),
//               builder: (_, __) => CustomPaint(
//                 painter: _GeofencePainter(
//                   customer: widget.customer,
//                   me: widget.me,
//                   pulseT: _pulse.value, // 0..1
//                   sweepT: _sweep.value, // 0..1
//                   locating: _locating,
//                   success: x.success,
//                   accent: cs.secondary, // brand accent / cyan
//                 ),
//               ),
//             ),

//             // 4) customer pin (teardrop) — anchored bottom-centre on the point
//             Align(
//               alignment: widget.customer.toAlignment(),
//               child: FractionalTranslation(
//                 translation: const Offset(0, -0.5), // lift so the tip sits on the point
//                 child: _CustomerPin(gradient: x.avatarGradient),
//               ),
//             ),

//             // 5) live GPS dot (centre dot is painted; this is the crisp core)
//             Align(
//               alignment: widget.me.toAlignment(),
//               child: _GpsCore(accent: cs.secondary, pulseT: _pulse.value),
//             ),

//             // 6) live-tracking pill (top inline-start)
//             PositionedDirectional(
//               start: 12,
//               top: 12,
//               child: _GlassPill(label: widget.liveTrackingLabel),
//             ),

//             // 7) directions FAB (bottom inline-end)
//             PositionedDirectional(
//               end: 12,
//               bottom: 40,
//               child: Material(
//                 color: cs.surface,
//                 borderRadius: BorderRadius.circular(14),
//                 elevation: 0,
//                 child: InkWell(
//                   borderRadius: BorderRadius.circular(14),
//                   onTap: widget.onDirections,
//                   child: Container(
//                     width: 44,
//                     height: 44,
//                     decoration: BoxDecoration(
//                       borderRadius: BorderRadius.circular(14),
//                       boxShadow: x.elev2,
//                       color: cs.surface,
//                     ),
//                     child: Icon(Symbols.assistant_direction, size: 24, color: x.brand),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // ============================================================================
// // The painter: geofence ring, two pulse rings, breathing dot halo, radar sweep.
// // Everything that needs to be pixel-registered to a map point lives here.
// // ============================================================================
// class _GeofencePainter extends CustomPainter {
//   final MapPoint customer, me;
//   final double pulseT, sweepT; // 0..1 normalized clocks
//   final bool locating;
//   final Color success, accent;

//   _GeofencePainter({
//     required this.customer,
//     required this.me,
//     required this.pulseT,
//     required this.sweepT,
//     required this.locating,
//     required this.success,
//     required this.accent,
//   });

//   // The web geofence is a fixed 132px circle → radius 66 on the 300-tall box.
//   static const double _geofenceRadius = 66;
//   // Pulse ring base size: 22px web → radius 11 at scale 1.
//   static const double _ringBase = 11;

//   Offset _at(MapPoint p, Size s) => Offset(p.x * s.width, p.y * s.height);

//   @override
//   void paint(Canvas canvas, Size size) {
//     final cCentre = _at(customer, size);
//     final meCentre = _at(me, size);

//     // ---- geofence: translucent fill + dashed stroke -----------------------
//     canvas.drawCircle(
//       cCentre,
//       _geofenceRadius,
//       Paint()..color = success.withOpacity(.16),
//     );
//     _drawDashedCircle(
//       canvas,
//       cCentre,
//       _geofenceRadius,
//       Paint()
//         ..style = PaintingStyle.stroke
//         ..strokeWidth = 2
//         ..color = success.withOpacity(.75),
//       dash: 6,
//       gap: 5,
//     );

//     // ---- radar sweep while acquiring a fix --------------------------------
//     if (locating) {
//       final sweepPaint = Paint()
//         ..shader = SweepGradient(
//           startAngle: 0,
//           endAngle: math.pi * 2,
//           transform: GradientRotation(sweepT * 2 * math.pi),
//           colors: [
//             accent.withOpacity(0),
//             accent.withOpacity(.55),
//             accent.withOpacity(0),
//           ],
//           stops: const [0.0, 0.16, 0.20], // ~60° lit wedge
//         ).createShader(Rect.fromCircle(center: cCentre, radius: _geofenceRadius));
//       canvas.save();
//       canvas.clipPath(Path()..addOval(Rect.fromCircle(center: cCentre, radius: _geofenceRadius)));
//       canvas.drawCircle(cCentre, _geofenceRadius, sweepPaint);
//       canvas.restore();
//     }

//     // ---- TWO expanding pulse rings around the GPS dot ---------------------
//     // Ring A: scale .55→2.4, opacity .55→0 (fades by 70% of the cycle).
//     _pulseRing(canvas, meCentre, t: pulseT, fromScale: .55, toScale: 2.4,
//         fromOpacity: .55, fadeBy: .70, color: accent);
//     // Ring B: same clock + 0.3 phase offset (≈ the web's .6s delay on a 2s loop),
//     //         scale .55→3.1, opacity .35→0 (fades by 80%).
//     _pulseRing(canvas, meCentre, t: (pulseT + .30) % 1.0, fromScale: .55, toScale: 3.1,
//         fromOpacity: .35, fadeBy: .80, color: accent);
//   }

//   void _pulseRing(Canvas canvas, Offset centre,
//       {required double t,
//       required double fromScale,
//       required double toScale,
//       required double fromOpacity,
//       required double fadeBy,
//       required Color color}) {
//     final eased = 1 - math.pow(1 - t, 2).toDouble(); // ease-out
//     final scale = fromScale + (toScale - fromScale) * eased;
//     final opacity = t >= fadeBy ? 0.0 : fromOpacity * (1 - t / fadeBy);
//     if (opacity <= 0) return;
//     canvas.drawCircle(centre, _ringBase * scale, Paint()..color = color.withOpacity(opacity));
//   }

//   void _drawDashedCircle(Canvas canvas, Offset c, double r, Paint p,
//       {required double dash, required double gap}) {
//     final circumference = 2 * math.pi * r;
//     final count = (circumference / (dash + gap)).floor();
//     final sweep = dash / r; // radians covered by one dash
//     final step = (dash + gap) / r;
//     for (int i = 0; i < count; i++) {
//       final start = i * step;
//       canvas.drawArc(Rect.fromCircle(center: c, radius: r), start, sweep, false, p);
//     }
//   }

//   @override
//   bool shouldRepaint(_GeofencePainter old) =>
//       old.pulseT != pulseT || old.sweepT != sweepT || old.locating != locating;
// }

// // ---- customer pin (gradient teardrop with a business glyph + stem) --------
// class _CustomerPin extends StatelessWidget {
//   final Gradient gradient;
//   const _CustomerPin({required this.gradient});
//   @override
//   Widget build(BuildContext context) => Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             width: 40,
//             height: 40,
//             decoration: BoxDecoration(
//               gradient: gradient,
//               shape: BoxShape.circle,
//               border: Border.all(color: Colors.white, width: 3),
//               boxShadow: const [BoxShadow(color: Color(0x730B1240), blurRadius: 14, offset: Offset(0, 6))],
//             ),
//             child: const Icon(Symbols.business, size: 22, fill: 1, color: Colors.white),
//           ),
//           Container(width: 2, height: 10, color: Colors.white, transform: Matrix4.translationValues(0, -1, 0)),
//         ],
//       );
// }

// // ---- GPS core: the crisp 18px accent dot with a white ring + soft breathing -
// class _GpsCore extends StatelessWidget {
//   final Color accent;
//   final double pulseT; // 0..1, used for the subtle 1→1.18→1 breathing
//   const _GpsCore({required this.accent, required this.pulseT});
//   @override
//   Widget build(BuildContext context) {
//     final breathe = 1 + 0.18 * math.sin(pulseT * 2 * math.pi).abs();
//     return Transform.scale(
//       scale: breathe,
//       child: Container(
//         width: 18,
//         height: 18,
//         decoration: BoxDecoration(
//           color: accent,
//           shape: BoxShape.circle,
//           border: Border.all(color: Colors.white, width: 3),
//           boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 8, offset: Offset(0, 2))],
//         ),
//       ),
//     );
//   }
// }

// // ---- frosted "live tracking" pill -----------------------------------------
// class _GlassPill extends StatelessWidget {
//   final String label;
//   const _GlassPill({required this.label});
//   @override
//   Widget build(BuildContext context) => Container(
//         height: 30,
//         padding: const EdgeInsets.symmetric(horizontal: 12),
//         decoration: BoxDecoration(
//           color: const Color(0x8C0A0B0F), // rgba(10,11,15,.55)
//           borderRadius: BorderRadius.circular(999),
//         ),
//         child: Row(mainAxisSize: MainAxisSize.min, children: [
//           Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF4ADE80), shape: BoxShape.circle)),
//           const SizedBox(width: 7),
//           Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
//         ]),
//       );
// }

// // Dark-mode map tint — equivalent of the web filter
// // `brightness(.74) contrast(1.06) saturate(.82) hue-rotate(-6deg)` (approx).
// const List<double> _kDarkMapMatrix = <double>[
//   0.78, 0.0, 0.0, 0, -18, //
//   0.0, 0.80, 0.0, 0, -18, //
//   0.0, 0.0, 0.86, 0, -14, //
//   0, 0, 0, 1, 0,
// ];
