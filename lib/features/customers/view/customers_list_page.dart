import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/theme.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../bloc/customers_bloc.dart';
import '../data/models/customer.dart';

class CustomersListPage extends StatefulWidget {
  const CustomersListPage({super.key});

  @override
  State<CustomersListPage> createState() => _CustomersListPageState();
}

class _CustomersListPageState extends State<CustomersListPage> {
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    context.read<CustomersBloc>().add(const CustomersLoadRequested());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      context.read<CustomersBloc>().add(CustomersSearchChanged(v.trim()));
    });
  }

  Future<void> _refresh() async {
    context.read<CustomersBloc>().add(const CustomersLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        BlocBuilder<CustomersBloc, CustomersState>(
          buildWhen: (p, n) => p.items != n.items,
          builder: (context, state) {
            final total = state.items.length;
            final active = state.items
                .where((c) => c.lastVisit != null && c.lastVisit!.checkOutTime == null)
                .length;
            return _CustomerStatsRow(total: total, active: active);
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: context.s.customersSearchHint,
            ),
          ),
        ),
        Expanded(
          child: BlocBuilder<CustomersBloc, CustomersState>(
            builder: (context, state) {
              final isLoading = state.status == CustomersStatus.loading;
              if (state.status == CustomersStatus.failure &&
                  state.items.isEmpty) {
                return ErrorView(
                  message: state.error?.localize(context) ??
                      context.s.errUnknown,
                  onRetry: _refresh,
                );
              }

              Widget body;
              if (isLoading) {
                body = const SkeletonList(
                  key: ValueKey('skeleton'),
                  itemCount: 8,
                );
              } else if (state.items.isEmpty) {
                body = ScaleFadeIn(
                  key: const ValueKey('empty'),
                  child: EmptyView(message: context.s.customersEmpty),
                );
              } else {
                body = ListView.separated(
                  key: const ValueKey('list'),
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  itemCount: state.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => AnimatedListItem(
                    index: i,
                    child: _CustomerTile(customer: state.items[i]),
                  ),
                );
              }

              return AppRefreshIndicator(
                onRefresh: _refresh,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: body,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Two summary tiles above the customer list (design screen 08): total
/// customers and active customers.
class _CustomerStatsRow extends StatelessWidget {
  final int total;
  final int active;
  const _CustomerStatsRow({required this.total, required this.active});

  @override
  Widget build(BuildContext context) {
    final x = context.x;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _StatTile(
              icon: Symbols.groups,
              value: total,
              label: context.s.customersStatTotal,
              tone: context.colors.primary,
              container: context.colors.primaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              icon: Symbols.trending_up,
              value: active,
              label: context.s.customersStatActive,
              tone: x.success,
              container: x.successContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  final Color tone;
  final Color container;
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.tone,
    required this.container,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: context.x.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: container,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Icon(icon, size: 20, fill: 1, color: tone),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 22,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
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

class _CustomerTile extends StatelessWidget {
  final Customer customer;
  const _CustomerTile({required this.customer});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final initial =
        customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?';
    final isActive = customer.lastVisit?.checkOutTime == null &&
        customer.lastVisit != null;
    final accent = isActive ? Colors.green.shade600 : colors.primary;
    final hasFooter = customer.phone != null ||
        customer.mobile != null ||
        customer.lastVisit != null;
    final addressText = customer.address ??
        '${customer.latitude.toStringAsFixed(4)}, '
            '${customer.longitude.toStringAsFixed(4)}';

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push('/customers/${customer.id}', extra: customer),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Colored side strip — green only when there's a live visit.
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.horizontal(
                  left: context.isRtl
                      ? Radius.zero
                      : const Radius.circular(12),
                  right: context.isRtl
                      ? const Radius.circular(12)
                      : Radius.zero,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: avatar + name/address + badge + chevron
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                colors.primary,
                                Color.lerp(
                                        colors.primary, colors.tertiary, 0.6) ??
                                    colors.primary,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    colors.primary.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initial,
                            style: TextStyle(
                              color: colors.onPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customer.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Icon(
                                    Icons.place_outlined,
                                    size: 13,
                                    color: colors.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      addressText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.text.bodySmall?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (customer.lastVisit != null) ...[
                          const SizedBox(width: 6),
                          _LastVisitBadge(lastVisit: customer.lastVisit!),
                        ],
                        const SizedBox(width: 4),
                        Icon(
                          context.isRtl
                              ? Icons.chevron_left
                              : Icons.chevron_right,
                          color: colors.onSurfaceVariant,
                          size: 22,
                        ),
                      ],
                    ),
                    if (hasFooter) ...[
                      const SizedBox(height: 12),
                      Divider(
                        height: 1,
                        color: colors.outlineVariant,
                      ),
                      const SizedBox(height: 10),
                      _MetaFooter(customer: customer),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaFooter extends StatelessWidget {
  final Customer customer;
  const _MetaFooter({required this.customer});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final phone = customer.phone ?? customer.mobile;
    final lastVisitTime = customer.lastVisit?.checkInTime;
    final isActive = customer.lastVisit?.checkOutTime == null &&
        customer.lastVisit != null;

    return Row(
      children: [
        if (phone != null) ...[
          Icon(Icons.phone_outlined,
              size: 14, color: colors.onSurfaceVariant),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              phone,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        if (phone != null && lastVisitTime != null) ...[
          const SizedBox(width: 10),
          Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(
              color: colors.onSurfaceVariant,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
        ],
        if (lastVisitTime != null) ...[
          Icon(
            isActive ? Icons.bolt_rounded : Icons.history_rounded,
            size: 14,
            color: isActive
                ? Colors.green.shade600
                : colors.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              isActive
                  ? context.s.visitsHistoryActiveBadge
                  : _relativeLong(lastVisitTime, context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(
                color: isActive
                    ? Colors.green.shade700
                    : colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _relativeLong(DateTime when, BuildContext context) {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'من ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'من ${diff.inHours} س';
    if (diff.inDays < 7) return 'من ${diff.inDays} يوم';
    return DateFormat('yyyy-MM-dd').format(when);
  }
}

class _LastVisitBadge extends StatelessWidget {
  final CustomerLastVisit lastVisit;
  const _LastVisitBadge({required this.lastVisit});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isActive = lastVisit.checkOutTime == null;
    final accent = isActive ? Colors.green.shade600 : colors.primary;
    final label = isActive
        ? context.s.visitsHistoryActiveBadge
        : (lastVisit.checkInTime != null
            ? _relativeShort(lastVisit.checkInTime!)
            : context.s.visitsHistoryCompletedBadge);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.circle : Icons.history_rounded,
            size: 9,
            color: accent,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  static String _relativeShort(DateTime when) {
    final now = DateTime.now();
    final diff = now.difference(when);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 30) return '${diff.inDays}d';
    return DateFormat('yyyy-MM-dd').format(when);
  }
}
