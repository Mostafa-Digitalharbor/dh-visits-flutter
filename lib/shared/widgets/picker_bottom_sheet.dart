import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/design/app_dimens.dart';
import '../../app/design/responsive.dart';
import '../../core/api/api_error_messages.dart';
import '../../core/api/api_exceptions.dart';
import '../extensions/context_extensions.dart';
import 'app_sheet.dart';
import 'debounced_search_field.dart';
import 'empty_view.dart';
import 'error_view.dart';
import 'skeleton.dart';

/// Generic bottom-sheet picker: a search field on top and a server-loaded list
/// below, re-queried as the user types. Returns the selected `T`, or `null`
/// if the user closes it without choosing.
Future<T?> showPickerBottomSheet<T>({
  required BuildContext context,
  required String title,
  required String searchHint,
  required Future<List<T>> Function(String? search) loader,
  required Widget Function(BuildContext, T) itemBuilder,
}) {
  return showAppSheet<T>(
    context: context,
    builder: (_) => _PickerSheet<T>(
      title: title,
      searchHint: searchHint,
      loader: loader,
      itemBuilder: itemBuilder,
    ),
  );
}

class _PickerSheet<T> extends StatefulWidget {
  final String title;
  final String searchHint;
  final Future<List<T>> Function(String? search) loader;
  final Widget Function(BuildContext, T) itemBuilder;

  const _PickerSheet({
    required this.title,
    required this.searchHint,
    required this.loader,
    required this.itemBuilder,
  });

  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
  /// Share of the available height the sheet takes when nothing covers it.
  static const double _heightFactor = 0.85;

  final _searchCtrl = TextEditingController();
  late Future<List<T>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loader(null);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _search(String query) {
    if (!mounted) return;
    // Block body, not `=>`: an arrow closure returns the assigned Future, and
    // setState asserts on that before marking the sheet dirty — in debug
    // builds every search and retry threw and the results never refreshed.
    final future = widget.loader(query.isEmpty ? null : query)
      // The FutureBuilder only subscribes on the next frame; a loader that
      // fails before then (offline) was reported as an *uncaught* error even
      // though the sheet shows it. ignore() only silences that report — the
      // builder still receives the error.
      ..ignore();
    setState(() {
      _future = future;
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = context.keyboardInset;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Bottom-anchored: lift the sheet above the keyboard the search field
        // raises, and shrink it to what is left, or the results would sit
        // behind the keyboard.
        final height = math.max(
          0.0,
          math.min(
            constraints.maxHeight * _heightFactor,
            constraints.maxHeight - keyboard,
          ),
        );
        return Padding(
          padding: EdgeInsets.only(bottom: keyboard),
          child: SizedBox(
            height: height,
            // One scroll view for header and results: on a short landscape
            // viewport with the keyboard up, a fixed header column overflowed.
            // Pinned, the header stays while results scroll under it, and is
            // clipped rather than overflowing when even it doesn't fit.
            child: CustomScrollView(
              slivers: [
                PinnedHeaderSliver(child: _header(context)),
                _results(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context) {
    return ColoredBox(
      color: context.colors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSheetHeader(
            title: widget.title,
            padding: EdgeInsetsDirectional.fromSTEB(
              context.r(Insets.x4),
              context.r(Insets.x3),
              context.r(Insets.x2),
              context.r(Insets.x2),
            ),
          ),
          DebouncedSearchField(
            hintText: widget.searchHint,
            controller: _searchCtrl,
            debounce: AppDurations.pickerDebounce,
            padding: const EdgeInsetsDirectional.fromSTEB(
              Insets.x4,
              0,
              Insets.x4,
              Insets.x2,
            ),
            onChanged: _search,
          ),
          const Divider(height: CompSz.hairline),
        ],
      ),
    );
  }

  Widget _results(BuildContext context) {
    return FutureBuilder<List<T>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SliverFillRemaining(child: SkeletonList());
        }
        if (snap.hasError) {
          final err = snap.error;
          return SliverFillRemaining(
            child: ErrorView(
              // A localized sentence (e.g. "no permission" when a picker source
              // like crm.lead is access-restricted), never the raw error — a
              // Dart exception's text is something the user can neither read
              // nor act on.
              message: err is ApiException
                  ? err.messageFor(context.s)
                  : context.s.errUnknown,
              reference: err is ApiException
                  ? err.supportReference
                  : ApiErrorCode.unknown.name,
              onRetry: () => _search(_searchCtrl.text.trim()),
            ),
          );
        }
        final items = snap.data ?? const [];
        if (items.isEmpty) {
          return SliverFillRemaining(
            child: EmptyView(
              icon: Icons.search_off_rounded,
              message: context.s.pickerNoResults,
            ),
          );
        }
        return SliverList.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: CompSz.hairline),
          itemBuilder: (ctx, i) => widget.itemBuilder(ctx, items[i]),
        );
      },
    );
  }
}
