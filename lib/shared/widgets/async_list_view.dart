import 'package:flutter/material.dart';

import '../../app/design/app_dimens.dart';
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

  /// Already localized. Falls back to a generic message when null.
  final String? errorMessage;

  final Future<void> Function() onRefresh;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  final String emptyMessage;
  final IconData emptyIcon;

  final int skeletonCount;
  final EdgeInsetsGeometry padding;

  /// Gap between rows. The visits list draws its own card margins, so it
  /// passes zero.
  final double separatorHeight;

  const AsyncListView({
    super.key,
    required this.items,
    required this.isLoading,
    required this.hasError,
    required this.errorMessage,
    required this.onRefresh,
    required this.itemBuilder,
    required this.emptyMessage,
    this.emptyIcon = Icons.inbox_outlined,
    this.skeletonCount = 8,
    this.padding = const EdgeInsets.fromLTRB(12, 4, 12, 16),
    this.separatorHeight = 8,
  });

  @override
  Widget build(BuildContext context) {
    // Only a failure with nothing to show takes over the screen. A refresh that
    // fails over existing rows keeps them — the caller reports that case with a
    // snackbar rather than throwing away data the user is reading.
    if (hasError && items.isEmpty) {
      return ErrorView(message: errorMessage ?? '', onRetry: onRefresh);
    }

    final Widget body;
    if (isLoading && items.isEmpty) {
      body = SkeletonList(
        key: const ValueKey('skeleton'),
        itemCount: skeletonCount,
      );
    } else if (items.isEmpty) {
      body = ScaleFadeIn(
        key: const ValueKey('empty'),
        child: EmptyView(icon: emptyIcon, message: emptyMessage),
      );
    } else {
      body = ListView.separated(
        key: const ValueKey('list'),
        padding: padding,
        itemCount: items.length,
        separatorBuilder: (_, __) => SizedBox(height: separatorHeight),
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
}
