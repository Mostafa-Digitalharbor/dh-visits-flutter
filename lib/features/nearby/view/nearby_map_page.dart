import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/design/app_colors.dart';
import '../../../core/constants.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../customers/data/models/customer.dart';
import '../bloc/nearby_bloc.dart';
import '../data/models/nearby_employee.dart';
import '../../../app/design/app_dimens.dart';
import 'nearby_bottom_panel.dart';

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

class _NearbyMapPageState extends State<NearbyMapPage> {
  final MapController _mapController = MapController();
  late final NearbyBloc _nearbyBloc;

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
  }

  @override
  void dispose() {
    _nearbyBloc.add(const NearbyStopped());
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
    final isDark = context.isDark;
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
                  color: AppColors.mapBackground(isDark),
                ),
              ),
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: AppConstants.defaultMapZoom,
                  maxZoom: AppConstants.mapMaxZoom,
                  minZoom: AppConstants.mapMinZoom,
                  backgroundColor: AppColors.mapBackground(isDark),
                ),
                children: [
                  // Pre-load tiles in a wider ring around the viewport so
                  // panning/zooming doesn't expose blank squares while new
                  // tiles download. Dark-mode tiles get a tint via tileBuilder.
                  AppMapTileLayer(
                    maxZoom: AppConstants.mapMaxZoom,
                    panBuffer: 2,
                    keepBuffer: 5,
                    tileBuilder: isDark ? _darkTileBuilder : null,
                  ),
                  // Radar ring, expanding outwards and fading as it goes.
                  //
                  // A gap between sweeps rather than a continuous one: this
                  // rebuilds a whole map layer per frame, and a real radar
                  // pings periodically anyway. See [AmbientPulse].
                  AmbientPulse(
                    period: const Duration(milliseconds: 1800),
                    rest: const Duration(milliseconds: 900),
                    curve: Curves.linear,
                    builder: (_, beat) => AnimatedBuilder(
                      animation: beat,
                      builder: (_, __) {
                        final t = beat.value;
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
                  // Top-left: NearbyBottomPanel covers the whole bottom edge
                  // and the zoom controls own the top-right.
                  const AppMapAttribution(alignment: Alignment.topLeft),
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
                child: NearbyBottomPanel(state: state),
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
  Widget build(BuildContext context) => MapPin.icon(
        icon: Icons.business_rounded,
        size: 54,
        // Thicker ring than an employee pin: this is the anchor of the screen
        // and has to stay readable under the pulsing radar ring.
        borderWidth: 3.5,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.25) ?? color],
        ),
      );
}

class _EmployeePin extends StatelessWidget {
  final NearbyEmployee employee;
  const _EmployeePin({required this.employee});

  @override
  Widget build(BuildContext context) => MapPin.label(
        text: InitialAvatar.initialOf(employee.name),
        tooltip: '${employee.name} • '
            '${context.s.unitMeters(employee.distanceMeters.toStringAsFixed(1))}',
        borderWidth: 2.8,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.redAccent, Colors.red.shade800],
        ),
      );
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

class _NearbyMapSkeleton extends StatelessWidget {
  const _NearbyMapSkeleton();

  @override
  Widget build(BuildContext context) {
    // The backdrop stands in for the map, so it uses the same colour the real
    // map does — a hardcoded white flashed as a bright sheet before the tiles
    // loaded in dark mode. The panel placeholder stays white on purpose: the
    // shimmer paints over it, exactly like every other SkeletonBox.
    return Stack(
      children: [
        Container(color: AppColors.mapBackground(context.isDark)),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: AppShimmer(
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
