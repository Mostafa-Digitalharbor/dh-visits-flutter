import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/utils/communications.dart';
import '../../../core/utils/relative_time.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../data/customers_repository.dart';
import '../data/models/customer.dart';
import 'customer_format.dart';

class CustomerDetailPage extends StatefulWidget {
  final int customerId;

  /// The row from the customer list, shown at once while the full record
  /// loads, and kept on screen if that load fails.
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
    // With a fallback on screen the load's failure would otherwise be silent:
    // the list's row stays up and nothing says it may be stale.
    _future = _fetch(announceFailure: widget.fallback != null);
  }

  /// Starts a load. When [announceFailure] is set, a failure is reported once
  /// here — not from the builder, which rebuilds and would repeat it.
  Future<Customer> _fetch({required bool announceFailure}) {
    final future = sl<CustomersRepository>().getById(widget.customerId);
    if (announceFailure) {
      future.then<void>((_) {}, onError: (Object error) {
        if (!mounted) return;
        final s = context.s;
        context.showSnack(
          s.commonRefreshFailedStale(CustomerFormat.loadFailure(context, error)),
          kind: SnackKind.error,
        );
      });
    }
    return future;
  }

  void _retry() {
    setState(() => _future = _fetch(announceFailure: false));
  }

  Future<void> _refresh() async {
    setState(() {
      _refreshing = true;
      _future = _fetch(announceFailure: true);
    });
    try {
      await _future;
    } catch (_) {
      // Reported by `_fetch`.
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Customer>(
      future: _future,
      builder: (context, snap) {
        final Customer? shown = switch (snap.connectionState) {
          // While a user-triggered refresh is in flight the skeleton shows, so
          // the reload is visible; on first open the list's row renders at once.
          != ConnectionState.done => _refreshing ? null : widget.fallback,
          _ when snap.hasError => widget.fallback,
          _ => snap.data,
        };
        if (shown != null) {
          return Scaffold(
            body: AppRefreshIndicator(
              onRefresh: _refresh,
              child: _CustomerBody(customer: shown),
            ),
          );
        }
        if (snap.connectionState != ConnectionState.done) {
          return const _DetailSkeleton();
        }
        return Scaffold(
          appBar: AppBar(title: Text(context.s.customerDetailTitle)),
          body: ErrorView(
            message: CustomerFormat.loadFailure(context, snap.error!),
            onRetry: _retry,
          ),
        );
      },
    );
  }
}

class _CustomerBody extends StatelessWidget {
  final Customer customer;
  const _CustomerBody({required this.customer});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final s = context.s;
    final lastVisit = customer.lastVisit;
    return CustomScrollView(
      // The refresh indicator needs a scrollable that always scrolls, even
      // when the content is shorter than the screen.
      physics: const AlwaysScrollableScrollPhysics(),
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
            title: AutoDirectionText(
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
                label: s.customerSectionInfo,
                padding: _sectionLabelPad,
              ),
              context.gapH(Insets.x1h),
              _CustomerInfoCard(customer: customer),
              if (lastVisit != null) ...[
                context.gapH(Insets.x4),
                SectionHeader.eyebrow(
                  label: s.customerLastVisit,
                  padding: _sectionLabelPad,
                ),
                context.gapH(Insets.x1h),
                _LastVisitCard(visit: lastVisit),
              ],
              context.gapH(Insets.x6),
              AppButton(
                label: s.wfCreateTitle,
                icon: Symbols.add,
                onPressed: () => context.push(AppRoutes.createVisit),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The customer's most recent visit; opens it.
class _LastVisitCard extends StatelessWidget {
  final CustomerLastVisit visit;
  const _LastVisitCard({required this.visit});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final checkIn = visit.checkInTime;
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push(AppRoutes.visitDetail(visit.id)),
      child: ListTile(
        leading: const Icon(Symbols.history),
        title: AutoDirectionText(
          visit.employeeName ?? s.visitFallbackTitle(visit.id),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          context.joinFacts([
            visit.isActive ? s.wfStateInProgress : s.wfStateDone,
            if (checkIn != null) RelativeTime.format(context, checkIn),
          ]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // `chevron_right` mirrors itself in Arabic (`matchTextDirection`).
        trailing: const Icon(Symbols.chevron_right),
      ),
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
      decoration: BoxDecoration(gradient: context.x.brandGradient),
      alignment: Alignment.center,
      // Symmetric, and large enough that the circle clears both the pinned
      // app-bar row above it and the collapsing title below.
      padding: EdgeInsets.symmetric(vertical: context.r(_heroPadV)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Not [InitialAvatar]'s default look: this one is a white wash over
          // the brand gradient rather than the gradient itself.
          InitialAvatar(
            name: customer.name,
            size: context.r(CompSz.avatarHero),
            background: colors.onPrimary.withValues(alpha: Alphas.wash),
            foreground: colors.onPrimary,
            icon: customer.isCompany ? Symbols.apartment : null,
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
            icon: Symbols.call,
            label: context.s.customerActionCall,
            color: context.x.success,
            onTap: phone == null
                ? null
                : () => context.openExternal(() => Communications.dial(phone)),
          ),
        ),
        context.gapW(Insets.x2h),
        if (email != null) ...[
          Expanded(
            child: _QuickAction(
              icon: Symbols.mail,
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
            icon: Symbols.directions,
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
              Icon(icon, fill: 1, size: context.r(IconSz.sm), color: effectiveColor),
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

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final cs = context.colors;
    final address = CustomerFormat.fullAddress(context, customer);
    final coordinates =
        CustomerFormat.coordinates(context, customer, precise: true);
    final phone = customer.phone;
    final email = customer.email;
    final website = customer.website;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Company vs individual badge.
          Container(
            padding: context.padSym(h: Insets.x3, v: Insets.x1h),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: Alphas.disabled),
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  customer.isCompany ? Symbols.apartment : Symbols.person,
                  size: context.r(IconSz.badge),
                  color: cs.onPrimaryContainer,
                ),
                context.gapW(Insets.x1h),
                Flexible(
                  child: Text(
                    customer.isCompany
                        ? s.customerTypeCompany
                        : s.customerTypeIndividual,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelLarge?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          context.gapH(Insets.x2h),
          if (address != null && address.isNotEmpty)
            InfoRow(icon: Symbols.location_on, text: address),
          if (phone != null)
            _TappableInfo(
              icon: Symbols.call,
              text: phone,
              onTap: () => Communications.dial(phone),
            ),
          if (email != null)
            _TappableInfo(
              icon: Symbols.mail,
              text: email,
              onTap: () => Communications.mailto(email),
            ),
          if (customer.jobPosition != null)
            InfoRow(
              icon: Symbols.work,
              text: s.commonLabeledValue(s.customerFieldJob, customer.jobPosition!),
            ),
          if (customer.parentCompanyName != null)
            InfoRow(
              icon: Symbols.business,
              text: s.commonLabeledValue(
                  s.customerFieldParent, customer.parentCompanyName!),
            ),
          if (website != null)
            _TappableInfo(
              icon: Symbols.link,
              text: website,
              onTap: () => Communications.openWeb(website),
            ),
          if (customer.vat != null)
            InfoRow(
              icon: Symbols.badge,
              text: s.commonLabeledValue(s.customerFieldVat, customer.vat!),
            ),
          // Coordinates: always shown (explicit requirement). Tappable when
          // present so the user can jump straight into their maps app.
          if (coordinates != null)
            _TappableInfo(
              icon: Symbols.my_location,
              text: coordinates,
              onTap: () => Communications.openInMaps(
                customer.latitude,
                customer.longitude,
                label: customer.name,
              ),
            )
          else
            InfoRow(
              icon: Symbols.my_location,
              text: s.commonLabeledValue(
                  s.customerFieldCoordinates, s.commonNoValue),
            ),
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
                    padding: context.padSym(h: Insets.x2h, v: Insets.x1),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// An [InfoRow] that hands its value to another app (dialler, mail, browser,
/// maps) and says so when no app can take it.
class _TappableInfo extends StatelessWidget {
  final IconData icon;
  final String text;
  final Future<bool> Function() onTap;
  const _TappableInfo({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => context.openExternal(onTap),
        borderRadius: BorderRadius.circular(Radii.xs),
        child: InfoRow(icon: icon, text: text),
      );
}

/// Inset of this screen's eyebrows: nudged in to line up with the card text
/// beneath them, and held tight to it.
const _sectionLabelPad = EdgeInsetsDirectional.only(
  start: Insets.x1,
  end: Insets.x1,
  bottom: Insets.hair,
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
