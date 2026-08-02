import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/design/app_colors.dart';
import '../../../core/constants.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/utils/communications.dart';
import '../../../core/utils/distance.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../data/models/visit.dart';
import '../data/visits_repository.dart';
import '../../../app/design/app_dimens.dart';

/// A compact geofence map on the visit-detail page.
///
/// Shows (when the data is available): the customer's office with the allowed
/// check-in radius, the employee's actual check-in / check-out GPS points, an
/// in-range / out-of-range badge, and a **Directions** button that hands off to
/// the system maps app.
///
/// The customer centre is resolved from, in order: the customer's `res.partner`
/// coordinates (fetched best-effort), then the visit's planned coordinates. The
/// whole card hides itself when there isn't a single coordinate to show, so it
/// never renders an empty grey box.
class VisitMapCard extends StatefulWidget {
  final Visit visit;
  const VisitMapCard({super.key, required this.visit});

  @override
  State<VisitMapCard> createState() => _VisitMapCardState();
}

class _VisitMapCardState extends State<VisitMapCard> {
  final MapController _map = MapController();
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

  @override
  void dispose() {
    super.dispose();
  }

  /// The customer office coordinate — fetched partner coords, else the visit's
  /// planned coordinate.
  LatLng? get _customer {
    final p = _partner;
    if (p != null) return LatLng(p.latitude, p.longitude);
    final v = widget.visit;
    if (v.latitude != null && v.longitude != null) {
      return LatLng(v.latitude!, v.longitude!);
    }
    return null;
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
    final points = [customer, checkIn, checkOut].whereType<LatLng>().toList();

    // Nothing to plot — hide the whole card rather than show an empty map.
    if (points.isEmpty) return const SizedBox.shrink();

    final primary = context.colors.primary;
    final isDark = context.isDark;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 200,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    color: AppColors.mapBackground(isDark),
                  ),
                ),
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: points.first,
                    initialZoom: AppConstants.mapZoomVisitDetail,
                    minZoom: AppConstants.mapMinZoom,
                    maxZoom: AppConstants.mapMaxZoom,
                    initialCameraFit: points.length > 1
                        ? CameraFit.coordinates(
                            coordinates: points,
                            padding: const EdgeInsets.all(48),
                            maxZoom: AppConstants.mapZoomVisitFitMax,
                          )
                        : null,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.pinchZoom |
                          InteractiveFlag.drag |
                          InteractiveFlag.doubleTapZoom,
                    ),
                  ),
                  children: [
                    const AppMapTileLayer(
                        maxZoom: AppConstants.mapMaxZoom, panBuffer: 2),
                    // Geofence + pulse ring, only when we know the customer point.
                    if (customer != null) ...[
                      // AmbientPulse, not a repeating controller: this rebuilds
                      // a whole flutter_map layer per frame, and it used to do
                      // so at 60fps for as long as the detail page stayed open.
                      // The ring already fades to nothing as it expands, so it
                      // rests invisibly between beats.
                      AmbientPulse(
                        period: const Duration(seconds: 2),
                        rest: const Duration(milliseconds: 1200),
                        curve: Curves.linear,
                        builder: (_, beat) => AnimatedBuilder(
                          animation: beat,
                          builder: (_, __) {
                            final t = beat.value;
                            return CircleLayer(
                              circles: [
                                CircleMarker(
                                  point: customer,
                                  radius: AppConstants.checkInRangeMeters *
                                      (1.0 + t * 0.6),
                                  useRadiusInMeter: true,
                                  color:
                                      primary.withValues(alpha: (1 - t) * 0.12),
                                  borderColor:
                                      primary.withValues(alpha: (1 - t) * 0.35),
                                  borderStrokeWidth: 1.5,
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
                            radius: AppConstants.checkInRangeMeters,
                            useRadiusInMeter: true,
                            color: primary.withValues(alpha: 0.12),
                            borderColor: primary,
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),
                    ],
                    MarkerLayer(
                      markers: [
                        if (customer != null)
                          Marker(
                            point: customer,
                            width: 46,
                            height: 46,
                            child: _Pin(
                              icon: Symbols.business,
                              color: primary,
                            ),
                          ),
                        if (checkIn != null)
                          Marker(
                            point: checkIn,
                            width: 40,
                            height: 40,
                            child: GestureDetector(
                              onTap: () => context.openExternal(
                                () => Communications.openInMaps(
                                  checkIn.latitude,
                                  checkIn.longitude,
                                  label: widget.visit.startLocation,
                                ),
                              ),
                              child: _Pin(
                                icon: Symbols.login,
                                color: Colors.green.shade600,
                              ),
                            ),
                          ),
                        if (checkOut != null)
                          Marker(
                            point: checkOut,
                            width: 40,
                            height: 40,
                            child: GestureDetector(
                              onTap: () => context.openExternal(
                                () => Communications.openInMaps(
                                  checkOut.latitude,
                                  checkOut.longitude,
                                  label: widget.visit.endLocation,
                                ),
                              ),
                              child: _Pin(
                                icon: Symbols.logout,
                                color: Colors.deepOrangeAccent.shade200,
                              ),
                            ),
                          ),
                      ],
                    ),
                    // Bottom-left: the recentre/navigate button owns the
                    // bottom-right corner of this card.
                    const AppMapAttribution(alignment: Alignment.bottomLeft),
                  ],
                ),
                // OSM tiles are always light, so in dark mode they glare out of
                // an otherwise dark screen. Knock them back with the same tint
                // the route map uses. IgnorePointer so the pins stay tappable.
                if (isDark)
                  IgnorePointer(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.22),
                    ),
                  ),
                // Directions hand-off.
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: _MapFab(
                    icon: Symbols.assistant_direction,
                    onTap: () => _openDirections(context),
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
    if (customer == null || p == null) return null;
    return haversineMeters(
        customer!.latitude, customer!.longitude, p.latitude, p.longitude);
  }

  @override
  Widget build(BuildContext context) {
    final startDist = _distance(checkIn);
    final endDist = _distance(checkOut);
    final hasAddress = address != null && address!.isNotEmpty;

    if (startDist == null && endDist == null && !hasAddress) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (startDist != null)
            _verdict(context, label: context.s.wfStartedLabel, distance: startDist),
          if (endDist != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child:
                  _verdict(context, label: context.s.wfEndedLabel, distance: endDist),
            ),
          if (hasAddress)
            Padding(
              padding: EdgeInsets.only(top: (startDist != null || endDist != null) ? 8 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.place_outlined,
                      size: 16, color: context.colors.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      address!,
                      style: context.text.bodySmall
                          ?.copyWith(color: context.colors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _verdict(BuildContext context,
      {required String label, required double distance}) {
    final s = context.s;
    final inRange = distance <= AppConstants.checkInRangeMeters;
    final tone = inRange ? Colors.green.shade700 : context.colors.error;
    return Row(
      children: [
        Icon(inRange ? Icons.verified_outlined : Icons.error_outline,
            size: 18, color: tone),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: context.text.bodySmall
                  ?.copyWith(color: context.colors.onSurfaceVariant),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(fontWeight: FontWeight.w700, color: tone),
                ),
                TextSpan(
                  text:
                      '${inRange ? s.visitDetailInRange : s.visitDetailOutRange} · '
                      '${s.visitDetailRangeMeta(distance.toStringAsFixed(0), AppConstants.checkInRangeMeters.toStringAsFixed(0))}',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A teardrop-style map pin: a coloured rounded square with a white border and
/// a centred icon, lifted so the visual weight sits above the point.
class _Pin extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _Pin({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) =>
      MapPin.icon(icon: icon, color: color, borderWidth: 3);
}

class _MapFab extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MapFab({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.btn)),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.btn),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: context.colors.primary),
        ),
      ),
    );
  }
}
