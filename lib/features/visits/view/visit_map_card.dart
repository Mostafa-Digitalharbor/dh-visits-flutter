import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/utils/communications.dart';
import '../../../core/utils/distance.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_map_tile_layer.dart';
import '../data/models/visit.dart';
import '../data/visits_repository.dart';

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

class _VisitMapCardState extends State<VisitMapCard>
    with SingleTickerProviderStateMixin {
  final MapController _map = MapController();
  late final AnimationController _pulse;
  PartnerLocation? _partner;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
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
    _pulse.dispose();
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

  Future<void> _openDirections() async {
    final target = _customer ?? _checkIn ?? _checkOut;
    if (target == null) return;
    await Communications.openInMaps(
      target.latitude,
      target.longitude,
      label: widget.visit.partnerName,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                    color: isDark
                        ? const Color(0xFF1A1A1A)
                        : const Color(0xFFE5E5E5),
                  ),
                ),
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: points.first,
                    initialZoom: 16,
                    minZoom: 3,
                    maxZoom: 22,
                    initialCameraFit: points.length > 1
                        ? CameraFit.coordinates(
                            coordinates: points,
                            padding: const EdgeInsets.all(48),
                            maxZoom: 17,
                          )
                        : null,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.pinchZoom |
                          InteractiveFlag.drag |
                          InteractiveFlag.doubleTapZoom,
                    ),
                  ),
                  children: [
                    const AppMapTileLayer(maxZoom: 22, panBuffer: 2),
                    // Geofence + pulse ring, only when we know the customer point.
                    if (customer != null) ...[
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, __) {
                          final t = _pulse.value;
                          return CircleLayer(
                            circles: [
                              CircleMarker(
                                point: customer,
                                radius: AppConstants.checkInRangeMeters *
                                    (1.0 + t * 0.6),
                                useRadiusInMeter: true,
                                color: primary.withValues(alpha: (1 - t) * 0.12),
                                borderColor:
                                    primary.withValues(alpha: (1 - t) * 0.35),
                                borderStrokeWidth: 1.5,
                              ),
                            ],
                          );
                        },
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
                            child: _Pin(
                              icon: Symbols.login,
                              color: Colors.green.shade600,
                            ),
                          ),
                        if (checkOut != null)
                          Marker(
                            point: checkOut,
                            width: 40,
                            height: 40,
                            child: _Pin(
                              icon: Symbols.logout,
                              color: Colors.deepOrangeAccent.shade200,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                // Directions hand-off.
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: _MapFab(
                    icon: Symbols.assistant_direction,
                    onTap: _openDirections,
                  ),
                ),
              ],
            ),
          ),
          _RangeFooter(
            customer: customer,
            checkIn: checkIn,
            address: _partner?.address ?? widget.visit.location,
          ),
        ],
      ),
    );
  }
}

/// The in-range / out-of-range chip + address line under the map. Renders the
/// range verdict only when both the customer point and a check-in point exist.
class _RangeFooter extends StatelessWidget {
  final LatLng? customer;
  final LatLng? checkIn;
  final String? address;
  const _RangeFooter({
    required this.customer,
    required this.checkIn,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    double? distance;
    if (customer != null && checkIn != null) {
      distance = haversineMeters(
        customer!.latitude,
        customer!.longitude,
        checkIn!.latitude,
        checkIn!.longitude,
      );
    }
    final inRange =
        distance != null && distance <= AppConstants.checkInRangeMeters;

    if (distance == null && (address == null || address!.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (distance != null)
            Row(
              children: [
                Icon(
                  inRange ? Icons.verified_outlined : Icons.error_outline,
                  size: 18,
                  color: inRange ? Colors.green.shade700 : context.colors.error,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    inRange ? s.visitDetailInRange : s.visitDetailOutRange,
                    style: context.text.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: inRange
                          ? Colors.green.shade700
                          : context.colors.error,
                    ),
                  ),
                ),
              ],
            ),
          if (distance != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 2),
              child: Text(
                s.visitDetailRangeMeta(
                  distance.toStringAsFixed(0),
                  AppConstants.checkInRangeMeters.toStringAsFixed(0),
                ),
                style: context.text.bodySmall
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ),
          if (address != null && address!.isNotEmpty)
            Row(
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
        ],
      ),
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
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}

class _MapFab extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MapFab({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
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
