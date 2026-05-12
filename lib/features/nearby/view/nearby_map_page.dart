import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../customers/data/models/customer.dart';
import '../bloc/nearby_bloc.dart';
import '../data/models/nearby_employee.dart';

class NearbyMapPage extends StatefulWidget {
  final int customerId;
  final Customer? customer;

  const NearbyMapPage({
    super.key,
    required this.customerId,
    this.customer,
  });

  @override
  State<NearbyMapPage> createState() => _NearbyMapPageState();
}

class _NearbyMapPageState extends State<NearbyMapPage>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late final NearbyBloc _nearbyBloc;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _nearbyBloc = context.read<NearbyBloc>();
    _nearbyBloc.add(
      NearbyStarted(
        customerId: widget.customerId,
        customer: widget.customer,
        radius: AppConstants.defaultRadiusMeters,
      ),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _nearbyBloc.add(const NearbyStopped());
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _zoomBy(double delta) {
    final cam = _mapController.camera;
    _mapController.move(cam.center, (cam.zoom + delta).clamp(3.0, 22.0));
  }

  void _centerOn(Customer customer) {
    _mapController.move(
      LatLng(customer.latitude, customer.longitude),
      AppConstants.defaultMapZoom,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.s.nearbyTitle),
        actions: [
          IconButton(
            tooltip: context.s.commonRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                context.read<NearbyBloc>().add(const NearbyRefreshed()),
          ),
        ],
      ),
      body: BlocConsumer<NearbyBloc, NearbyState>(
        listenWhen: (prev, curr) =>
            prev.customer != curr.customer && curr.customer != null,
        listener: (context, state) {
          final customer = state.customer!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            try {
              _mapController.move(
                LatLng(customer.latitude, customer.longitude),
                AppConstants.defaultMapZoom,
              );
            } catch (_) {
              // Map not ready yet — initialCenter still places it correctly.
            }
          });
        },
        builder: (context, state) {
          if (state.status == NearbyStatus.loading && state.customer == null) {
            return const _NearbyMapSkeleton();
          }
          if (state.customer == null) {
            return ErrorView(
              message: state.error?.localize(context) ??
                  context.s.errCustomerLoadFailed,
              onRetry: () => _nearbyBloc.add(
                NearbyStarted(
                  customerId: widget.customerId,
                  customer: widget.customer,
                ),
              ),
            );
          }
          final customer = state.customer!;
          final center = LatLng(customer.latitude, customer.longitude);
          final primary = context.colors.primary;

          return Stack(
            children: [
              // Neutral background sits under the map so any tile that
              // hasn't downloaded yet shows as a soft grey instead of pure
              // white squares.
              Positioned.fill(
                child: Container(
                  color: isDark
                      ? const Color(0xFF1A1A1A)
                      : const Color(0xFFE5E5E5),
                ),
              ),
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: AppConstants.defaultMapZoom,
                  maxZoom: 22,
                  minZoom: 3,
                  backgroundColor: isDark
                      ? const Color(0xFF1A1A1A)
                      : const Color(0xFFE5E5E5),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName:
                        'com.digitalharbor.location_gps',
                    // OSM tiles only exist up to zoom 19. Beyond that we let
                    // flutter_map upscale the last available tile (a bit
                    // blurry but still legible) instead of showing blank
                    // tiles.
                    maxNativeZoom: 19,
                    maxZoom: 22,
                    // Pre-load tiles in a wider ring around the viewport so
                    // panning/zooming doesn't expose blank squares while new
                    // tiles download.
                    panBuffer: 2,
                    keepBuffer: 5,
                    tileBuilder: isDark ? _darkTileBuilder : null,
                  ),
                  // Pulsing radar ring (subtle, expanding outwards)
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, __) {
                      final t = _pulseCtrl.value;
                      return CircleLayer(
                        circles: [
                          CircleMarker(
                            point: center,
                            radius: state.radius * (1.0 + t * 1.8),
                            useRadiusInMeter: true,
                            color: primary.withValues(alpha: (1 - t) * 0.18),
                            borderColor:
                                primary.withValues(alpha: (1 - t) * 0.45),
                            borderStrokeWidth: 1.8,
                          ),
                        ],
                      );
                    },
                  ),
                  // Solid 10m boundary — the actual radius the user cares about
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: center,
                        radius: state.radius,
                        useRadiusInMeter: true,
                        color: primary.withValues(alpha: 0.15),
                        borderColor: primary,
                        borderStrokeWidth: 3,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      // Customer pin (center)
                      Marker(
                        point: center,
                        width: 54,
                        height: 54,
                        alignment: Alignment.center,
                        child: _CustomerPin(color: primary),
                      ),
                      // Nearby employees
                      ...state.employees.map(
                        (e) => Marker(
                          point: LatLng(e.latitude, e.longitude),
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          child: _EmployeePin(employee: e),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Right-side map controls
              Positioned(
                right: 12,
                top: 16,
                child: Column(
                  children: [
                    _MapFab(icon: Icons.add, onTap: () => _zoomBy(1)),
                    const SizedBox(height: 8),
                    _MapFab(icon: Icons.remove, onTap: () => _zoomBy(-1)),
                    const SizedBox(height: 14),
                    _MapFab(
                      icon: Icons.my_location,
                      onTap: () => _centerOn(customer),
                    ),
                  ],
                ),
              ),
              // Bottom info panel
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: _BottomPanel(state: state),
              ),
            ],
          );
        },
      ),
    );
  }
}

Widget _darkTileBuilder(BuildContext context, Widget tileWidget, TileImage tile) {
  return ColorFiltered(
    colorFilter: const ColorFilter.matrix([
      -1, 0, 0, 0, 255,
      0, -1, 0, 0, 255,
      0, 0, -1, 0, 255,
      0, 0, 0, 1, 0,
    ]),
    child: tileWidget,
  );
}

class _CustomerPin extends StatelessWidget {
  final Color color;
  const _CustomerPin({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            Color.lerp(color, Colors.black, 0.25) ?? color,
          ],
        ),
        border: Border.all(color: Colors.white, width: 3.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const Icon(
        Icons.business_rounded,
        color: Colors.white,
        size: 26,
      ),
    );
  }
}

class _EmployeePin extends StatelessWidget {
  final NearbyEmployee employee;
  const _EmployeePin({required this.employee});

  @override
  Widget build(BuildContext context) {
    final initial =
        employee.name.isNotEmpty ? employee.name[0].toUpperCase() : '?';
    return Tooltip(
      message:
          '${employee.name} • ${employee.distanceMeters.toStringAsFixed(1)}م',
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.redAccent, Colors.red.shade800],
          ),
          border: Border.all(color: Colors.white, width: 2.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _MapFab extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MapFab({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Icon(icon, size: 20, color: colors.onSurface),
        ),
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  final NearbyState state;
  const _BottomPanel({required this.state});

  @override
  Widget build(BuildContext context) {
    final tf = DateFormat('HH:mm:ss');
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.colors.primaryContainer,
                ),
                alignment: Alignment.center,
                child: Icon(Icons.business_rounded,
                    size: 18, color: context.colors.onPrimaryContainer),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.customer?.name ?? '-',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      context.s.nearbyRadiusLabel(
                          state.radius.toStringAsFixed(0)),
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (state.lastRefresh != null)
                Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 13, color: context.colors.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      tf.format(state.lastRefresh!),
                      style: context.text.labelSmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (state.employees.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.person_off_outlined,
                      size: 18,
                      color: context.colors.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      state.status == NearbyStatus.success
                          ? context.s.nearbyEmpty
                          : context.s.commonLoading,
                      style: TextStyle(
                          color: context.colors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 86,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: state.employees.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) =>
                    _EmployeeCard(employee: state.employees[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  final NearbyEmployee employee;
  const _EmployeeCard({required this.employee});

  @override
  Widget build(BuildContext context) {
    final tf = DateFormat('HH:mm:ss');
    final initial =
        employee.name.isNotEmpty ? employee.name[0].toUpperCase() : '?';
    return Container(
      width: 180,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.redAccent,
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  employee.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall?.copyWith(
                    color: context.colors.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  context.s.unitMeters(
                      employee.distanceMeters.toStringAsFixed(1)),
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.onErrorContainer,
                  ),
                ),
                if (employee.lastUpdate != null)
                  Text(
                    tf.format(employee.lastUpdate!),
                    style: context.text.labelSmall?.copyWith(
                      color: context.colors.onErrorContainer
                          .withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbyMapSkeleton extends StatelessWidget {
  const _NearbyMapSkeleton();

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Stack(
        children: [
          Container(color: Colors.white),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
