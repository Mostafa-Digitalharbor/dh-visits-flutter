import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/constants.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/utils/communications.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../data/customers_repository.dart';
import '../data/models/customer.dart';

class CustomerDetailPage extends StatefulWidget {
  final int customerId;

  /// Used as cached data while the network fetch is in-flight, and as a
  /// fallback if the `/api/customers/<id>` endpoint fails (e.g. backend bug).
  /// Passed via `context.push(..., extra: customer)` from the list.
  final Customer? fallback;

  const CustomerDetailPage({
    super.key,
    required this.customerId,
    this.fallback,
  });

  @override
  State<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends State<CustomerDetailPage> {
  late Future<Customer> _future;

  /// True only while the user-triggered pull-to-refresh is running. Lets us
  /// distinguish "first visit to page" (show fallback instantly) from
  /// "user wants fresh data" (show skeleton so the refresh is obvious).
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _future = sl<CustomersRepository>().getById(widget.customerId);
  }

  void _reload() {
    setState(() {
      _future = sl<CustomersRepository>().getById(widget.customerId);
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _refreshing = true;
      _future = sl<CustomersRepository>().getById(widget.customerId);
    });
    try {
      await _future;
    } catch (e) {
      // Only surface refresh errors when the user explicitly triggered the
      // refresh. Initial-load errors are absorbed silently because the
      // fallback Customer keeps the page usable.
      if (mounted) {
        final msg = e is ApiException
            ? e.localize(context)
            : context.s.errCustomerLoadFailed;
        context.showSnack(msg);
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Customer>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            // While a user-triggered refresh is in-flight, always show the
            // skeleton so the user can see the data is being re-fetched.
            // On the initial open of the page, fall back to the cached
            // Customer (from the list) so the page renders instantly.
            if (widget.fallback != null && !_refreshing) {
              return RefreshIndicator(
                onRefresh: _refresh,
                child: _CustomerBody(customer: widget.fallback!),
              );
            }
            return const _DetailSkeleton();
          }
          if (snap.hasError) {
            if (widget.fallback != null) {
              // Backend detail endpoint failed — silently fall back to the
              // data we already have from the list. Refresh failures are
              // announced via _refresh()'s snackbar, not from inside the
              // builder (which can rebuild many times and spam snackbars).
              return RefreshIndicator(
                onRefresh: _refresh,
                child: _CustomerBody(customer: widget.fallback!),
              );
            }
            final message = snap.error is ApiException
                ? (snap.error as ApiException).localize(context)
                : context.s.errCustomerLoadFailed;
            return Scaffold(
              appBar: AppBar(title: Text(context.s.customerDetailTitle)),
              body: ErrorView(message: message, onRetry: _reload),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: _CustomerBody(customer: snap.data!),
          );
        },
      ),
    );
  }
}

class _CustomerBody extends StatelessWidget {
  final Customer customer;
  const _CustomerBody({required this.customer});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 200,
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.symmetric(
              horizontal: 56,
              vertical: 14,
            ),
            title: Text(
              customer.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            background: _CustomerHero(customer: customer),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          sliver: SliverList.list(
            children: [
              _QuickActionsRow(customer: customer),
              const SizedBox(height: 14),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (customer.address != null) ...[
                      InfoRow(
                          icon: Icons.place_outlined, text: customer.address!),
                      const SizedBox(height: 4),
                    ],
                    if (customer.phone != null) ...[
                      InfoRow(
                          icon: Icons.phone_outlined, text: customer.phone!),
                      const SizedBox(height: 4),
                    ],
                    if (customer.mobile != null &&
                        customer.mobile != customer.phone) ...[
                      InfoRow(
                          icon: Icons.smartphone_outlined,
                          text: customer.mobile!),
                      const SizedBox(height: 4),
                    ],
                    InfoRow(
                      icon: Icons.my_location,
                      text: '${customer.latitude.toStringAsFixed(6)}, '
                          '${customer.longitude.toStringAsFixed(6)}',
                    ),
                  ],
                ),
              ),
              if (customer.lastVisit != null) ...[
                const SizedBox(height: 16),
                _SectionLabel(label: context.s.customerLastVisit),
                const SizedBox(height: 6),
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(customer.lastVisit!.employeeName ??
                        '#${customer.lastVisit!.id}'),
                    subtitle: Text(customer.lastVisit!.checkOutTime != null
                        ? context.s.wfStateDone
                        : context.s.wfStateInProgress),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              AppButton(
                label: context.s.wfCreateTitle,
                icon: Icons.add,
                onPressed: () => context.push('/visits/create'),
              ),
              const SizedBox(height: 10),
              AppButton.secondary(
                label: context.s.customerActionNearby(
                  AppConstants.defaultRadiusMeters.toStringAsFixed(0),
                ),
                icon: Icons.map_outlined,
                onPressed: () => context.push(
                  '/customers/${customer.id}/nearby',
                  extra: customer,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CustomerHero extends StatelessWidget {
  final Customer customer;
  const _CustomerHero({required this.customer});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary,
            Color.lerp(colors.primary, colors.tertiary, 0.5) ?? colors.primary,
          ],
        ),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.only(top: 56, bottom: 56),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.onPrimary.withValues(alpha: 0.18),
            ),
            alignment: Alignment.center,
            child: Text(
              customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
              style: TextStyle(
                color: colors.onPrimary,
                fontSize: 32,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  final Customer customer;
  const _QuickActionsRow({required this.customer});

  @override
  Widget build(BuildContext context) {
    final phone = customer.phone ?? customer.mobile;
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.phone_rounded,
            label: context.s.customerActionCall,
            color: Colors.green.shade600,
            onTap: phone == null ? null : () => Communications.dial(phone),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickAction(
            icon: Icons.directions_rounded,
            label: context.s.customerActionNavigate,
            color: context.colors.primary,
            onTap: () => Communications.openInMaps(
              customer.latitude,
              customer.longitude,
              label: customer.name,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final effectiveColor = enabled
        ? color
        : context.colors.onSurfaceVariant.withValues(alpha: 0.5);
    return Material(
      color: enabled
          ? color.withValues(alpha: 0.10)
          : context.colors.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: effectiveColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: context.text.titleSmall?.copyWith(
                  color: effectiveColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 2),
      child: Text(
        label.toUpperCase(),
        style: context.text.labelSmall?.copyWith(
          color: context.colors.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}


class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.s.customerDetailTitle)),
      body: AppShimmer(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            SkeletonCard(height: 160),
            SizedBox(height: 12),
            SkeletonCard(height: 90),
            SizedBox(height: 20),
            SkeletonBox(width: double.infinity, height: 48, radius: 12),
            SizedBox(height: 10),
            SkeletonBox(width: double.infinity, height: 48, radius: 12),
          ],
        ),
      ),
    );
  }
}
