import 'package:flutter/material.dart';

import '../../app/design/app_dimens.dart';
import '../../app/design/responsive.dart';
import '../../core/api/api_error_messages.dart';
import '../../core/api/api_exceptions.dart';
import '../../core/constants.dart';
import '../extensions/context_extensions.dart';
import 'animated_list_item.dart';
import 'app_refresh_indicator.dart';
import 'empty_view.dart';
import 'error_view.dart';
import 'skeleton.dart';

/// The loading → error → empty → content ladder every list screen needs, in one
/// place.
///
/// The customers and employees screens carried byte-identical copies of this
/// ladder (skeleton keys, animation curves, padding, separator height and all),
/// and the visits list a third near-copy. Duplicating it meant a fix to one —
/// like rendering a failure instead of an empty state — silently missed the
/// others.
///
/// Ordering matters and is deliberate: **failure is checked before empty**. A
/// failed fetch rendered as "nothing here" reads as authoritative good news and
/// is worse than no answer at all.
class AsyncListView<T> extends StatelessWidget {
  final List<T> items;
  final bool isLoading;
  final bool hasError;

  /// Already localized. When null the message comes from [error], or the
  /// generic "something went wrong" sentence — never an empty screen.
  final String? errorMessage;

  /// The failure behind [hasError], when the caller has it: supplies the
  /// message when [errorMessage] is null, and the support reference printed
  /// under it.
  final ApiException? error;

  final Future<void> Function() onRefresh;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  final String emptyMessage;
  final IconData emptyIcon;

  final int skeletonCount;

  /// Design-space padding around the list; scaled with the device.
  final EdgeInsetsGeometry padding;

  /// Gap between rows, in design-space dp. The visits list draws its own card
  /// margins, so it passes zero.
  final double separatorHeight;

  /// Content above the rows that scrolls away with them — a search box, a
  /// summary. A fixed column above the list instead overflowed short screens
  /// once the keyboard was up (a phone on its side while searching).
  final Widget? header;

  const AsyncListView({
    super.key,
    required this.items,
    required this.isLoading,
    required this.hasError,
    required this.errorMessage,
    required this.onRefresh,
    required this.itemBuilder,
    required this.emptyMessage,
    this.error,
    this.emptyIcon = Icons.inbox_outlined,
    this.skeletonCount = defaultSkeletonCount,
    this.padding = const EdgeInsetsDirectional.fromSTEB(
      Insets.x3,
      Insets.x1,
      Insets.x3,
      Insets.x4,
    ),
    this.separatorHeight = Insets.x2,
    this.header,
  });

  /// Placeholder rows while the first page loads — about a phone screen's worth.
  static const int defaultSkeletonCount = 8;

  @override
  Widget build(BuildContext context) {
    final header = this.header;
    if (header != null) return _withHeader(context, header);
    // Only a failure with nothing to show takes over the screen. A refresh that
    // fails over existing rows keeps them — the caller reports that case with a
    // snackbar rather than throwing away data the user is reading.
    if (hasError && items.isEmpty) {
      return ErrorView(
        message: errorMessage ??
            error?.messageFor(context.s) ??
            context.s.errUnknown,
        reference: error?.supportReference,
        onRetry: onRefresh,
      );
    }

    final Widget body;
    if (isLoading && items.isEmpty) {
      body = SkeletonList(
        key: WidgetKeys.listSkeleton,
        itemCount: skeletonCount,
      );
    } else if (items.isEmpty) {
      // EmptyView centres through AdaptiveCenter, whose scroll view only takes
      // a drag when its content overflows — so "nothing here" could not be
      // pulled to refresh, which is exactly when users pull. Always-scrollable
      // physics (over the platform's own) let the pull reach the indicator.
      final scroll = ScrollConfiguration.of(context);
      body = ScrollConfiguration(
        key: WidgetKeys.listEmpty,
        behavior: scroll.copyWith(
          physics: AlwaysScrollableScrollPhysics(
            parent: scroll.getScrollPhysics(context),
          ),
        ),
        child: ScaleFadeIn(
          child: EmptyView(icon: emptyIcon, message: emptyMessage),
        ),
      );
    } else {
      final direction = Directionality.of(context);
      final resolved = padding.resolve(direction);
      body = ListView.separated(
        key: WidgetKeys.listContent,
        padding: EdgeInsets.fromLTRB(
          context.r(resolved.left),
          context.rh(resolved.top),
          context.r(resolved.right),
          context.rh(resolved.bottom),
        ),
        itemCount: items.length,
        separatorBuilder: (_, __) => context.gapH(separatorHeight),
        itemBuilder: (context, i) => AnimatedListItem(
          index: i,
          child: itemBuilder(context, items[i], i),
        ),
      );
    }

    return AppRefreshIndicator(
      onRefresh: onRefresh,
      child: AnimatedSwitcher(
        duration: AppDurations.listSwitch,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: body,
      ),
    );
  }

  /// The same ladder with [header] scrolling above it, all in one scroll view.
  Widget _withHeader(BuildContext context, Widget header) {
    final Widget state;
    if (hasError && items.isEmpty) {
      // `hasScrollBody: true`: with `false` the sliver measures its child's
      // intrinsic height, which the error and empty views (built on a
      // LayoutBuilder) cannot report — the state threw instead of rendering.
      state = SliverFillRemaining(
        hasScrollBody: true,
        child: ErrorView(
          message: errorMessage ??
              error?.messageFor(context.s) ??
              context.s.errUnknown,
          reference: error?.supportReference,
          onRetry: onRefresh,
        ),
      );
    } else if (isLoading && items.isEmpty) {
      state = SliverToBoxAdapter(
        child: SizedBox(
          height: SkeletonList.rowHeight * skeletonCount,
          child: SkeletonList(
            key: WidgetKeys.listSkeleton,
            itemCount: skeletonCount,
          ),
        ),
      );
    } else if (items.isEmpty) {
      state = SliverFillRemaining(
        key: WidgetKeys.listEmpty,
        hasScrollBody: true,
        child: ScaleFadeIn(
          child: EmptyView(icon: emptyIcon, message: emptyMessage),
        ),
      );
    } else {
      final resolved = padding.resolve(Directionality.of(context));
      state = SliverPadding(
        key: WidgetKeys.listContent,
        padding: EdgeInsets.fromLTRB(
          context.r(resolved.left),
          context.rh(resolved.top),
          context.r(resolved.right),
          context.rh(resolved.bottom),
        ),
        sliver: SliverList.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => context.gapH(separatorHeight),
          itemBuilder: (context, i) => AnimatedListItem(
            index: i,
            child: itemBuilder(context, items[i], i),
          ),
        ),
      );
    }

    return AppRefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [SliverToBoxAdapter(child: header), state],
      ),
    );
  }
}
