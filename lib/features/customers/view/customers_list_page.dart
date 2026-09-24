import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/design/app_decor.dart';
import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/utils/app_number.dart';
import '../../../core/utils/relative_time.dart';
import '../../../shared/bloc/searchable_list_bloc.dart';
import '../../../shared/extensions/bloc_extensions.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../bloc/customers_bloc.dart';
import '../data/models/customer.dart';
import 'customer_format.dart';

class CustomersListPage extends StatefulWidget {
  const CustomersListPage({super.key});

  @override
  State<CustomersListPage> createState() => _CustomersListPageState();
}

class _CustomersListPageState extends State<CustomersListPage> {
  @override
  void initState() {
    super.initState();
    context.read<CustomersBloc>().add(const ListLoadRequested());
  }

  /// Lasts as long as the reload, so the pull-to-refresh spinner does too.
  Future<void> _refresh() {
    final bloc = context.read<CustomersBloc>()..add(const ListLoadRequested());
    return bloc.untilSettled((s) => s.isLoading);
  }

  @override
  Widget build(BuildContext context) {
    // Listener as well as builder: when a refresh fails while a list is
    // already on screen, the error view can't take over (items aren't empty)
    // and the failure would pass in complete silence — spinner retracts,
    // stale data stays, no explanation.
    return BlocConsumer<CustomersBloc, CustomersState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status && curr.hasError && curr.items.isNotEmpty,
      listener: (context, state) =>
          context.showStaleRefreshSnack(state.error),
      builder: (context, state) => AsyncListView<Customer>(
        items: state.items,
        isLoading: state.isLoading,
        hasError: state.hasError,
        errorMessage: state.error?.localize(context),
        error: state.error,
        onRefresh: _refresh,
        emptyIcon: Symbols.groups,
        emptyMessage: context.s.customersEmpty,
        // The summary and the search box scroll with the rows, so a short
        // screen with the keyboard up still has room for the list.
        header: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CustomerStatsRow(
              total: state.items.length,
              active: state.items.where((c) => c.hasActiveVisit).length,
            ),
            DebouncedSearchField(
              // Design-space: the field scales its own padding.
              padding: const EdgeInsetsDirectional.fromSTEB(
                Insets.x4,
                Insets.x1,
                Insets.x4,
                Insets.x2,
              ),
              hintText: context.s.customersSearchHint,
              onChanged: (q) =>
                  context.read<CustomersBloc>().add(ListSearchChanged(q)),
            ),
          ],
        ),
        itemBuilder: (_, customer, __) => _CustomerTile(customer: customer),
      ),
    );
  }
}

/// Two summary tiles above the customer list (design screen 08): total
/// customers and customers with a visit running now.
class _CustomerStatsRow extends StatelessWidget {
  final int total;
  final int active;
  const _CustomerStatsRow({required this.total, required this.active});

  @override
  Widget build(BuildContext context) {
    final x = context.x;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        context.r(Insets.x4),
        context.rh(Insets.x3),
        context.r(Insets.x4),
        context.rh(Insets.x2),
      ),
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
          context.gapW(Insets.x3),
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

  /// Tight line height so the figure and its label read as one block.
  static const double _valueLineHeight = 1.1;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Container(
      padding: context.padSym(h: Insets.x3h, v: Insets.x3),
      decoration: AppDecor.panel(context, shadow: false),
      child: Row(
        children: [
          IconBadge(
            icon: icon,
            color: tone,
            background: container,
            size: context.r(CompSz.badgeLg),
            iconSize: context.r(IconSz.sm),
            radius: Radii.sm,
            fill: 1,
          ),
          context.gapW(Insets.x2h),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppNumber.whole(value),
                  maxLines: 1,
                  style: AppType.number(FontSz.greeting, cs.onSurface)
                      .copyWith(height: _valueLineHeight),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: FontSz.sm,
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

/// 52 — the list avatar: a step up from [CompSz.avatar] so the initial stays
/// legible next to a two-line name block.
const double _tileAvatarSize = 52.0;

/// The coloured strip on the card's leading edge.
const double _accentStripWidth = 4.0;

/// The avatar's soft brand shadow.
const _avatarShadowAlpha = 0.25;
const _avatarShadowBlur = 8.0;
const _avatarShadowOffset = Offset(0, 3);

class _CustomerTile extends StatelessWidget {
  final Customer customer;
  const _CustomerTile({required this.customer});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lastVisit = customer.lastVisit;
    final accent = customer.hasActiveVisit ? context.x.success : colors.primary;
    final hasFooter =
        customer.phone != null || customer.mobile != null || lastVisit != null;
    final addressText = customer.address ??
        CustomerFormat.coordinates(context, customer) ??
        context.s.commonNoValue;

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () =>
          context.push(AppRoutes.customerDetail(customer.id), extra: customer),
      // A start-edge border rather than a strip widget beside the content: the
      // card clips it to its own rounded shape, and it follows the content's
      // height without an IntrinsicHeight pass per row. Green only while a
      // visit is running.
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: BorderDirectional(
            start: BorderSide(color: accent, width: _accentStripWidth),
          ),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            context.r(Insets.x3h),
            context.r(Insets.x3h),
            context.r(Insets.x3),
            context.r(Insets.x3h),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: avatar + name/address + badge + chevron
              Row(
                children: [
                  InitialAvatar(
                    name: customer.name,
                    size: context.r(_tileAvatarSize),
                    shadow: [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: _avatarShadowAlpha),
                        blurRadius: _avatarShadowBlur,
                        offset: _avatarShadowOffset,
                      ),
                    ],
                  ),
                  context.gapW(Insets.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AutoDirectionText(
                          customer.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        context.gapH(Insets.x1),
                        Row(
                          children: [
                            Icon(
                              Symbols.location_on,
                              size: context.r(IconSz.meta),
                              color: colors.onSurfaceVariant,
                            ),
                            context.gapW(Insets.x1),
                            Expanded(
                              child: AutoDirectionText(
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
                  if (lastVisit != null) ...[
                    context.gapW(Insets.x1h),
                    // Flexible, not a bare child: at 320dp with the text
                    // scale at its 1.25 ceiling the badge, the chevron
                    // and the avatar together left the name/address
                    // column about 14dp, which is narrower than the
                    // address row's own icon — so that row overflowed by
                    // 2px. Letting the badge give way instead ellipsises
                    // a label that is already a rough "3h ago".
                    Flexible(child: _LastVisitBadge(lastVisit: lastVisit)),
                  ],
                  context.gapW(Insets.x1),
                  // `chevron_right` mirrors itself in Arabic
                  // (`matchTextDirection`); choosing `chevron_left` for RTL
                  // flipped it back to pointing the wrong way.
                  Icon(
                    Symbols.chevron_right,
                    color: colors.onSurfaceVariant,
                    size: context.r(IconSz.tile),
                  ),
                ],
              ),
              if (hasFooter) ...[
                context.gapH(Insets.x3),
                Divider(height: 1, color: colors.outlineVariant),
                context.gapH(Insets.x2h),
                _MetaFooter(customer: customer),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The small dot between two footer facts.
const double _footerDotSize = 3.0;

class _MetaFooter extends StatelessWidget {
  final Customer customer;
  const _MetaFooter({required this.customer});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final phone = customer.phone ?? customer.mobile;
    final lastVisitTime = customer.lastVisit?.checkInTime;
    final isActive = customer.hasActiveVisit;
    final activeColor = context.x.success;
    final glyph = context.r(IconSz.inline);

    return Row(
      children: [
        if (phone != null) ...[
          Icon(Symbols.call, size: glyph, color: colors.onSurfaceVariant),
          context.gapW(Insets.x1),
          Flexible(
            // Phone numbers are left-to-right in both languages.
            child: Text(
              phone,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.ltr,
              style: context.text.bodySmall?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        if (phone != null && lastVisitTime != null) ...[
          context.gapW(Insets.x2h),
          Container(
            width: _footerDotSize,
            height: _footerDotSize,
            decoration: BoxDecoration(
              color: colors.onSurfaceVariant,
              shape: BoxShape.circle,
            ),
          ),
          context.gapW(Insets.x2h),
        ],
        if (lastVisitTime != null) ...[
          Icon(
            isActive ? Symbols.bolt : Symbols.history,
            size: glyph,
            color: isActive ? activeColor : colors.onSurfaceVariant,
          ),
          context.gapW(Insets.x1),
          Flexible(
            child: Text(
              isActive
                  ? context.s.visitsHistoryActiveBadge
                  : RelativeTime.format(context, lastVisitTime),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(
                color: isActive ? activeColor : colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _LastVisitBadge extends StatelessWidget {
  final CustomerLastVisit lastVisit;
  const _LastVisitBadge({required this.lastVisit});

  /// A small pill: a dense dot and label, with a faint outline so it holds its
  /// shape on the card surface.
  static const double _dotSize = 9.0;
  static const double _outlineAlpha = 0.35;

  @override
  Widget build(BuildContext context) {
    final isActive = lastVisit.isActive;
    final accent = isActive ? context.x.success : context.colors.primary;
    final checkIn = lastVisit.checkInTime;
    // RelativeTime, not a hand-built "5d": it pluralises properly in Arabic
    // and reads "now" for a check-in stamped slightly ahead of this device.
    final label = isActive
        ? context.s.visitsHistoryActiveBadge
        : checkIn != null
            ? RelativeTime.format(context, checkIn)
            : context.s.visitsHistoryCompletedBadge;

    return TonePill(
      label: label,
      icon: isActive ? Symbols.circle : Symbols.history,
      color: accent,
      // Safe here — the caller wraps this badge in a Flexible, so it is laid
      // out against a bounded width.
      flexibleLabel: true,
      iconSize: context.r(_dotSize),
      fontSize: FontSz.tiny,
      radius: Radii.sm,
      tintAlpha: Alphas.tint,
      borderAlpha: _outlineAlpha,
      padding: context.padSym(h: Insets.x2, v: Insets.x1),
    );
  }
}
