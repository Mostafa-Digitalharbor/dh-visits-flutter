import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/design/app_typography.dart';
import '../../../app/design/responsive.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/constants.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/utils/communications.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../data/customers_repository.dart';
import '../data/models/customer.dart';
import '../../../app/design/app_dimens.dart';

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
        context.showSnack(msg, kind: SnackKind.error);
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
              return AppRefreshIndicator(
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
              return AppRefreshIndicator(
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
          return AppRefreshIndicator(
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
          expandedHeight: _heroHeight(context),
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          flexibleSpace: FlexibleSpaceBar(
            // The horizontal inset clears the back button on one side and the
            // (possible) actions on the other, so the collapsed title never
            // slides under them.
            titlePadding: EdgeInsets.symmetric(
              horizontal: context.r(Insets.x12 + Insets.x2),
              vertical: context.r(Insets.x3h),
            ),
            title: Text(
              customer.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onPrimary,
                fontWeight: FontWeight.w600,
                fontSize: FontSz.xl,
              ),
            ),
            background: _CustomerHero(customer: customer),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            context.r(Insets.screen),
            context.r(Insets.screen),
            context.r(Insets.screen),
            context.rh(Insets.x6),
          ),
          sliver: SliverList.list(
            children: [
              _QuickActionsRow(customer: customer),
              context.gapH(Insets.x3h),
              SectionHeader.eyebrow(
                label: context.s.customerSectionInfo,
                padding: _sectionLabelPad,
              ),
              context.gapH(Insets.x1h),
              _CustomerInfoCard(customer: customer),
              if (customer.lastVisit != null) ...[
                context.gapH(Insets.x4),
                SectionHeader.eyebrow(
                  label: context.s.customerLastVisit,
                  padding: _sectionLabelPad,
                ),
                context.gapH(Insets.x1h),
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(
                      customer.lastVisit!.employeeName ??
                          '#${customer.lastVisit!.id}',
                    ),
                    subtitle: Text(
                      customer.lastVisit!.checkOutTime != null
                          ? context.s.wfStateDone
                          : context.s.wfStateInProgress,
                    ),
                    trailing: Icon(
                      context.isRtl ? Icons.chevron_left : Icons.chevron_right,
                    ),
                    onTap: () => context.push(
                      AppRoutes.visitDetail(customer.lastVisit!.id),
                      extra: customer.lastVisit,
                    ),
                  ),
                ),
              ],
              context.gapH(Insets.x6),
              AppButton(
                label: context.s.wfCreateTitle,
                icon: Icons.add,
                onPressed: () => context.push(AppRoutes.createVisit),
              ),
              context.gapH(Insets.x2h),
              AppButton.secondary(
                label: context.s.customerActionNearby(
                  AppConstants.defaultRadiusMeters.toStringAsFixed(0),
                ),
                icon: Icons.map_outlined,
                onPressed: customer.hasCoordinates
                    ? () => context.push(
                        AppRoutes.customerNearby(customer.id),
                        extra: customer,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Space above and below the hero circle — enough to clear the pinned app-bar
/// row on one side and the collapsing title on the other.
const double _heroPadV = 56.0;

/// Height of the collapsing header, **derived from what the hero stacks** and
/// scaled on the same axis as its contents.
///
/// Both facts are load-bearing. The two used to be independent constants, and
/// scaling them on different axes — the circle by width, the header by height —
/// broke the screen in landscape: a 720×360 viewport scales width *up* to 1.2×
/// and height *down* to 0.85×, so the circle grew while its box shrank and the
/// hero overflowed by 12dp. Deriving the height means the box is by
/// construction big enough for the content, at every viewport.
double _heroHeight(BuildContext context) =>
    context.r(CompSz.avatarHero + _heroPadV * 2 + Insets.cardGap);

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
      // Symmetric, and large enough that the circle clears both the pinned
      // app-bar row above it and the collapsing title below.
      padding: EdgeInsets.symmetric(vertical: context.r(_heroPadV)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Not [InitialAvatar]: this one is a white wash over the brand
          // gradient rather than the gradient itself, and swaps the initial
          // for a building glyph on company records.
          Container(
            width: context.r(CompSz.avatarHero),
            height: context.r(CompSz.avatarHero),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.onPrimary.withValues(alpha: Alphas.wash),
            ),
            alignment: Alignment.center,
            child: customer.isCompany
                ? Icon(
                    Icons.apartment_rounded,
                    color: colors.onPrimary,
                    size: context.r(IconSz.hero),
                  )
                : Text(
                    InitialAvatar.initialOf(customer.name),
                    style: TextStyle(
                      color: colors.onPrimary,
                      fontSize: FontSz.heroInitial,
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
    final email = customer.email;
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.phone_rounded,
            label: context.s.customerActionCall,
            color: Colors.green.shade600,
            onTap: phone == null
                ? null
                : () => context.openExternal(() => Communications.dial(phone)),
          ),
        ),
        context.gapW(Insets.x2h),
        if (email != null) ...[
          Expanded(
            child: _QuickAction(
              icon: Icons.mail_rounded,
              label: context.s.customerActionEmail,
              color: context.colors.tertiary,
              onTap: () =>
                  context.openExternal(() => Communications.mailto(email)),
            ),
          ),
          context.gapW(Insets.x2h),
        ],
        Expanded(
          child: _QuickAction(
            icon: Icons.directions_rounded,
            label: context.s.customerActionNavigate,
            color: context.colors.primary,
            onTap: customer.hasCoordinates
                ? () => context.openExternal(
                    () => Communications.openInMaps(
                      customer.latitude,
                      customer.longitude,
                      label: customer.name,
                    ),
                  )
                : null,
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
        : context.colors.onSurfaceVariant.withValues(alpha: Alphas.disabled);
    return Material(
      color: enabled
          ? color.withValues(alpha: Alphas.tint)
          : context.colors.surfaceContainerHighest
              .withValues(alpha: Alphas.disabled),
      borderRadius: BorderRadius.circular(Radii.btn),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.btn),
        child: Padding(
          padding: context.padSym(h: Insets.x3, v: Insets.x3h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: context.r(IconSz.sm), color: effectiveColor),
              context.gapW(Insets.x2),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: context.text.titleSmall?.copyWith(
                    color: effectiveColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The enriched contact card: a company/individual badge, tags, and every
/// detail we hold for the customer (address, phone, email, job, related
/// company, website, tax id) plus the always-shown geo coordinates.
class _CustomerInfoCard extends StatelessWidget {
  final Customer customer;
  const _CustomerInfoCard({required this.customer});

  String? _fullAddress(BuildContext context) {
    final parts = <String>[
      if (customer.street != null && customer.street!.isNotEmpty)
        customer.street!,
      [
        if (customer.city != null && customer.city!.isNotEmpty) customer.city!,
        if (customer.stateName != null && customer.stateName!.isNotEmpty)
          customer.stateName!,
        if (customer.zip != null && customer.zip!.isNotEmpty) customer.zip!,
      ].join(' '),
      if (customer.countryName != null && customer.countryName!.isNotEmpty)
        customer.countryName!,
    ].map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (parts.isNotEmpty) return parts.join(context.isRtl ? '، ' : ', ');
    return customer.address; // fallback to contact_address
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final cs = context.colors;
    final address = _fullAddress(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Company vs individual badge.
          Container(
            padding: context.padSym(h: Insets.x3, v: Insets.x1h + 1),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: Alphas.disabled),
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  customer.isCompany
                      ? Icons.apartment_rounded
                      : Icons.person_rounded,
                  size: context.r(IconSz.badge),
                  color: cs.onPrimaryContainer,
                ),
                context.gapW(Insets.x1h),
                Text(
                  customer.isCompany
                      ? s.customerTypeCompany
                      : s.customerTypeIndividual,
                  style: context.text.labelLarge?.copyWith(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          context.gapH(Insets.x2h),
          if (address != null && address.isNotEmpty)
            InfoRow(icon: Icons.place_outlined, text: address),
          if (customer.phone != null)
            InkWell(
              onTap: () => context.openExternal(
                () => Communications.dial(customer.phone!),
              ),
              child: InfoRow(icon: Icons.phone_outlined, text: customer.phone!),
            ),
          if (customer.email != null)
            InkWell(
              onTap: () => context.openExternal(
                () => Communications.mailto(customer.email!),
              ),
              child: InfoRow(icon: Icons.mail_outline, text: customer.email!),
            ),
          if (customer.jobPosition != null)
            InfoRow(
              icon: Icons.work_outline,
              text: '${s.customerFieldJob}: ${customer.jobPosition!}',
            ),
          if (customer.parentCompanyName != null)
            InfoRow(
              icon: Icons.business_outlined,
              text: '${s.customerFieldParent}: ${customer.parentCompanyName!}',
            ),
          if (customer.website != null)
            InkWell(
              onTap: () => context.openExternal(
                () => Communications.openWeb(customer.website!),
              ),
              child: InfoRow(icon: Icons.link, text: customer.website!),
            ),
          if (customer.vat != null)
            InfoRow(
              icon: Icons.badge_outlined,
              text: '${s.customerFieldVat}: ${customer.vat!}',
            ),
          // Coordinates: always shown (explicit requirement). Tappable when
          // present so the user can jump straight into their maps app.
          if (customer.hasCoordinates)
            InkWell(
              onTap: () => context.openExternal(
                () => Communications.openInMaps(
                  customer.latitude,
                  customer.longitude,
                  label: customer.name,
                ),
              ),
              child: InfoRow(
                icon: Icons.my_location,
                text:
                    '${customer.latitude.toStringAsFixed(6)}, '
                    '${customer.longitude.toStringAsFixed(6)}',
              ),
            )
          else
            const InfoRow(icon: Icons.my_location, text: '—'),
          if (customer.categories.isNotEmpty) ...[
            context.gapH(Insets.x2h),
            Text(
              s.customerFieldTags,
              style: context.text.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            context.gapH(Insets.x1h),
            Wrap(
              spacing: context.r(Insets.x1h),
              runSpacing: context.r(Insets.x1h),
              children: [
                for (final t in customer.categories)
                  TonePill(
                    label: t,
                    color: cs.tertiary,
                    fontSize: context.text.labelMedium?.fontSize ?? FontSz.sm,
                    fontWeight: FontWeight.w600,
                    padding: context.padSym(h: Insets.x2h, v: Insets.x1 + 1),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Inset of this screen's eyebrows: nudged in to line up with the card text
/// beneath them, and held tight to it.
const _sectionLabelPad = EdgeInsetsDirectional.only(
  start: Insets.x1,
  end: Insets.x1,
  bottom: 2,
);

/// Placeholder heights for [_DetailSkeleton] — the measured heights of the
/// blocks they stand in for, so the page does not jump when the data lands.
const double _infoCardHeight = 160.0;
const double _lastVisitCardHeight = 90.0;

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.s.customerDetailTitle)),
      body: AppShimmer(
        child: ListView(
          padding: context.padAll(Insets.screen),
          children: [
            // Stands in for the info card, the last-visit card, and the two
            // full-width buttons at the foot of the real page.
            SkeletonCard(height: context.r(_infoCardHeight)),
            context.gapH(Insets.x3),
            SkeletonCard(height: context.r(_lastVisitCardHeight)),
            context.gapH(Insets.x5),
            SkeletonBox(
                width: double.infinity,
                height: context.fixedH(IconSz.hit),
                radius: Radii.sm),
            context.gapH(Insets.x2h),
            SkeletonBox(
                width: double.infinity,
                height: context.fixedH(IconSz.hit),
                radius: Radii.sm),
          ],
        ),
      ),
    );
  }
}
