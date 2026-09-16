import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/design/app_colors.dart';
import '../../../app/design/app_dimens.dart';
import '../../../app/design/responsive.dart';
import '../../../core/constants.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/utils/app_number.dart';
import '../../../core/utils/communications.dart';
import '../../../core/utils/distance.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../data/models/visit.dart';
import '../data/models/visit_location_log.dart';
import '../data/visits_repository.dart';
import 'visit_labels.dart';
import 'visit_trail_layers.dart';

/// A compact geofence map on the visit-detail page.
///
/// Shows (when the data is available): the customer's office with the allowed
/// check-in radius, the employee's actual check-in / check-out GPS points, an
/// in-range / out-of-range badge, and a **Directions** button that hands off to
/// the system maps app.
///
/// Once the visit has been started it also draws the **GPS trail** — the thread
/// of every position logged between Start and End — so the same card answers
/// both "was the rep at the customer?" and "what route did they take to get
/// there?". [onOpenTrail] surfaces the full-screen version of it.
///
/// The customer centre is resolved from, in order: the customer's `res.partner`
/// coordinates (fetched best-effort), then the visit's planned coordinates. The
/// whole card hides itself when there isn't a single coordinate to show, so it
/// never renders an empty grey box.
class VisitMapCard extends StatefulWidget {
  final Visit visit;

  /// The path to draw between the start and end pins. Null while it is still
  /// loading; empty when the visit has no logged positions.
  final VisitTrack? trail;

  /// Opens the full-screen trail. The button only appears when there is a path
  /// worth opening.
  final VoidCallback? onOpenTrail;

  const VisitMapCard({
    super.key,
    required this.visit,
    this.trail,
    this.onOpenTrail,
  });

  /// The most of the screen's height the map may take, so a landscape phone
  /// still shows the page around it.
  static const double _maxHeightFraction = 0.5;

  /// The customer pin, larger than the check-in / check-out pins it anchors.
  static const double _customerPin = 46;
  static const double _visitPin = 40;
  static const double _pinRing = 3;

  /// Tiles kept loaded beyond the viewport, so a short drag on the small card
  /// doesn't expose blank squares.
  static const int _tilePanBuffer = 2;

  /// Width of the geofence circle's outline.
  static const double _fenceStroke = 2;

  /// The geofence pulse: one beat, the pause after it, and how far past the
  /// fence (as a fraction of its radius) the ring travels while fading.
  static const _pulseBeat = Duration(seconds: 2);
  static const _pulseRest = Duration(milliseconds: 1200);
  static const double _pulseGrowth = 0.6;

  @override
  State<VisitMapCard> createState() => _VisitMapCardState();
}

class _VisitMapCardState extends State<VisitMapCard> {
  PartnerLocation? _partner;

  @override
  void initState() {
    super.initState();
    _loadPartner();
  }

  Future<void> _loadPartner() async {
    final pid = widget.visit.partnerId;
    if (pid == null) return;
    final loc = await sl<VisitsRepository>().partnerLocation(pid);
    if (loc != null && mounted) setState(() => _partner = loc);
  }

  /// The customer office coordinate — fetched partner coords, else the visit's
  /// planned coordinate.
  LatLng? get _customer {
    final p = _partner;
    if (p != null) return LatLng(p.latitude, p.longitude);
    final v = widget.visit;
    return v.hasCustomerLocation ? LatLng(v.latitude!, v.longitude!) : null;
  }

  LatLng? get _checkIn {
    final v = widget.visit;
    return v.hasStartLocation ? LatLng(v.startLat!, v.startLng!) : null;
  }

  LatLng? get _checkOut {
    final v = widget.visit;
    return v.hasEndLocation ? LatLng(v.endLat!, v.endLng!) : null;
  }

  Future<void> _openDirections(BuildContext context) async {
    final target = _customer ?? _checkIn ?? _checkOut;
    if (target == null) return;
    await context.openExternal(
      () => Communications.openInMaps(
        target.latitude,
        target.longitude,
        label: widget.visit.partnerName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customer = _customer;
    final checkIn = _checkIn;
    final checkOut = _checkOut;
    final trail = widget.trail ?? VisitTrack.empty;
    // The trail's own vertices go into the camera fit, not just its endpoints:
    // a route that loops away from the customer would otherwise be framed out
    // of the card and the thread would run off the edge.
    final points = [
      ...[customer, checkIn, checkOut].whereType<LatLng>(),
      ...TrailLayers.points(trail),
    ];

    // Nothing to plot — hide the whole card rather than show an empty map.
    if (points.isEmpty) return const SizedBox.shrink();

    final height = math.min(
      context.fixedH(CompSz.mapCard),
      context.hp(VisitMapCard._maxHeightFraction),
    );
    final fabInset = context.r(Insets.x3);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: height,
            child: AppMap(
              // The camera is fitted once, when the map is built. The trail
              // usually arrives after the card first shows (it loads in
              // parallel), so the map is rebuilt once when a path appears —
              // otherwise the fit never included it. Later polls add points
              // without refitting, so the user's own pan and zoom survive.
              key: ValueKey(trail.hasPath),
              initialCenter: points.first,
              initialZoom: AppConstants.mapZoomVisitDetail,
              initialCameraFit: AppMap.fitOrNull(
                points,
                padding: context.padAll(Insets.x12),
                maxZoom: AppConstants.mapZoomVisitFitMax,
              ),
              panBuffer: VisitMapCard._tilePanBuffer,
              // Start-side: the map buttons own the end-side corner.
              attributionAlignment: context.isRtl
                  ? Alignment.bottomRight
                  : Alignment.bottomLeft,
              layers: [
                if (customer != null) ..._geofence(context, customer),
                // Under the pins: the thread is context for them, and a line
                // drawn over a pin reads as crossing it out. Road-matched
                // where a match exists; the recorded fixes joined otherwise.
                MatchedRouteBuilder(
                  traces: [trail.logs.trace],
                  builder: (context, geometries) => TrailLayers.polyline(
                    context,
                    trail,
                    path: geometries.first.path(),
                  ),
                ),
                TrailLayers.endpoints(
                  context,
                  trail,
                  live: widget.visit.isTrackingLive,
                  size: TrailLayers.pinSizeCompact,
                ),
                MarkerLayer(
                  markers: [
                    if (customer != null)
                      Marker(
                        point: customer,
                        width: VisitMapCard._customerPin,
                        height: VisitMapCard._customerPin,
                        child: MapPin.icon(
                          icon: Symbols.business,
                          color: context.colors.primary,
                          borderWidth: VisitMapCard._pinRing,
                        ),
                      ),
                    // Suppressed once the trail is drawn: its own start and
                    // end pins sit on the very same coordinates (the
                    // Start/End actions write the first and last points of
                    // the trail), so keeping both stacks two pins on one spot.
                    if (checkIn != null && !trail.hasPath)
                      _visitPin(
                        context,
                        point: checkIn,
                        icon: Symbols.login,
                        color: AppColors.routeStart,
                        label: widget.visit.startLocation,
                      ),
                    if (checkOut != null && !trail.hasPath)
                      _visitPin(
                        context,
                        point: checkOut,
                        icon: Symbols.logout,
                        color: AppColors.routeEnd,
                        label: widget.visit.endLocation,
                      ),
                  ],
                ),
              ],
              overlays: [
                // Directions hand-off, plus the full-screen trail when there
                // is a path to expand.
                PositionedDirectional(
                  end: fabInset,
                  bottom: fabInset,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (trail.hasPath && widget.onOpenTrail != null) ...[
                        MapFab.rounded(
                          icon: Symbols.timeline,
                          onTap: widget.onOpenTrail!,
                          semanticLabel: context.s.trailOpenFull,
                        ),
                        context.gapH(Insets.x2),
                      ],
                      MapFab.rounded(
                        icon: Symbols.assistant_direction,
                        onTap: () => _openDirections(context),
                        semanticLabel: context.s.mapOpenDirections,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _RangeFooter(
            customer: customer,
            checkIn: checkIn,
            checkOut: checkOut,
            address: _partner?.address ?? widget.visit.location,
          ),
        ],
      ),
    );
  }

  /// The check-in radius around the customer, with a ring that beats outward
  /// from it.
  List<Widget> _geofence(BuildContext context, LatLng customer) {
    final primary = context.colors.primary;
    const radius = AppConstants.checkInRangeMeters;
    return [
      // AmbientPulse, not a repeating controller: this rebuilds a whole
      // flutter_map layer per frame, and it used to do so at 60fps for as
      // long as the detail page stayed open. The ring fades to nothing as it
      // expands, so it rests invisibly between beats.
      AmbientPulse(
        period: VisitMapCard._pulseBeat,
        rest: VisitMapCard._pulseRest,
        curve: Curves.linear,
        builder: (_, beat) => AnimatedBuilder(
          animation: beat,
          builder: (_, __) {
            final fade = 1 - beat.value;
            return CircleLayer(
              circles: [
                CircleMarker(
                  point: customer,
                  radius: radius * (1 + beat.value * VisitMapCard._pulseGrowth),
                  useRadiusInMeter: true,
                  color: primary.withValues(alpha: fade * Alphas.tint),
                  borderColor: primary.withValues(alpha: fade * Alphas.border),
                  borderStrokeWidth: CompSz.outlineWidth,
                ),
              ],
            );
          },
        ),
      ),
      CircleLayer(
        circles: [
          CircleMarker(
            point: customer,
            radius: radius,
            useRadiusInMeter: true,
            color: primary.withValues(alpha: Alphas.tint),
            borderColor: primary,
            borderStrokeWidth: VisitMapCard._fenceStroke,
          ),
        ],
      ),
    ];
  }

  /// A check-in or check-out pin that opens the point in the maps app.
  Marker _visitPin(
    BuildContext context, {
    required LatLng point,
    required IconData icon,
    required Color color,
    required String? label,
  }) {
    return Marker(
      point: point,
      width: VisitMapCard._visitPin,
      height: VisitMapCard._visitPin,
      child: GestureDetector(
        onTap: () => context.openExternal(
          () => Communications.openInMaps(
            point.latitude,
            point.longitude,
            label: label,
          ),
        ),
        child: MapPin.icon(
          icon: icon,
          color: color,
          borderWidth: VisitMapCard._pinRing,
        ),
      ),
    );
  }
}

/// The in-range / out-of-range verdicts (for the check-in **and** check-out
/// points, so a manager can confirm the rep both arrived at and left from the
/// customer) plus the address line under the map.
class _RangeFooter extends StatelessWidget {
  final LatLng? customer;
  final LatLng? checkIn;
  final LatLng? checkOut;
  final String? address;
  const _RangeFooter({
    required this.customer,
    required this.checkIn,
    required this.checkOut,
    required this.address,
  });

  double? _distance(LatLng? p) {
    final c = customer;
    if (c == null || p == null) return null;
    return haversineMeters(c.latitude, c.longitude, p.latitude, p.longitude);
  }

  @override
  Widget build(BuildContext context) {
    final startDist = _distance(checkIn);
    final endDist = _distance(checkOut);
    final place = address;
    final hasAddress = place != null && place.isNotEmpty;

    if (startDist == null && endDist == null && !hasAddress) {
      return const SizedBox.shrink();
    }

    final muted = context.colors.onSurfaceVariant;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        context.r(Insets.x3),
        context.r(Insets.x2h),
        context.r(Insets.x3),
        context.r(Insets.x3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (startDist != null)
            _verdict(
              context,
              label: context.s.wfStartedLabel,
              distance: startDist,
            ),
          if (startDist != null && endDist != null) context.gapH(Insets.x1h),
          if (endDist != null)
            _verdict(context, label: context.s.wfEndedLabel, distance: endDist),
          if (hasAddress) ...[
            if (startDist != null || endDist != null) context.gapH(Insets.x2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.place_outlined,
                  size: context.r(IconSz.xs),
                  color: muted,
                ),
                context.gapW(Insets.x1h),
                Expanded(
                  child: Text(
                    place,
                    style: context.text.bodySmall?.copyWith(color: muted),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _verdict(
    BuildContext context, {
    required String label,
    required double distance,
  }) {
    final s = context.s;
    final inRange = distance <= AppConstants.checkInRangeMeters;
    final tone = inRange ? context.visitSuccess : context.colors.error;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          inRange ? Icons.verified_outlined : Icons.error_outline,
          size: context.r(IconSz.label),
          color: tone,
        ),
        context.gapW(Insets.x1h),
        Expanded(
          // Text.rich, not RichText: RichText ignores the user's text scale.
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: s.wfLabelColon(label),
                  style: TextStyle(fontWeight: FontWeight.w700, color: tone),
                ),
                const TextSpan(text: ' '),
                TextSpan(
                  text: context.joinFacts([
                    inRange ? s.visitDetailInRange : s.visitDetailOutRange,
                    s.wfRangeDistance(AppNumber.distance(s, distance)),
                    s.wfRangeRadius(
                      AppNumber.distance(s, AppConstants.checkInRangeMeters),
                    ),
                  ]),
                ),
              ],
            ),
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
