import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/api/api_exceptions.dart';
import '../extensions/context_extensions.dart';
import 'empty_view.dart';
import 'error_view.dart';
import 'skeleton.dart';
import '../../app/design/app_dimens.dart';

/// Generic bottom-sheet picker: opens a modal with a search field on top and
/// a server-loaded list below. Re-queries with debounce on every keystroke.
/// Returns the selected `T` or `null` if the user closes without choosing.
Future<T?> showPickerBottomSheet<T>({
  required BuildContext context,
  required String title,
  required String searchHint,
  required Future<List<T>> Function(String? search) loader,
  required Widget Function(BuildContext, T) itemBuilder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _PickerSheet<T>(
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
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  late Future<List<T>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loader(null);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _future = widget.loader(query.isEmpty ? null : query);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom;
    // The sheet is bottom-anchored, so a height fixed at 85% of the screen
    // puts the result list *behind* the keyboard that the search field just
    // raised — leaving the user typing at an invisible list. Lift the sheet
    // by the keyboard inset and shrink it to what's actually left, with a
    // floor so it can't collapse on a short landscape viewport.
    final available = mq.size.height - mq.padding.top;
    final height = math.max(
      math.min(available * 0.85, available - keyboard),
      available * 0.4,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SizedBox(
        height: height,
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: context.text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              autofocus: false,
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearchChanged('');
                          setState(() {});
                        },
                      ),
                isDense: true,
                filled: true,
                fillColor: colors.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.sm),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (q) {
                _onSearchChanged(q);
                setState(() {});
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<T>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const SkeletonList(itemCount: 8);
                }
                if (snap.hasError) {
                  final err = snap.error;
                  return ErrorView(
                    // Show a friendly localized message (e.g. "no permission"
                    // when a picker source like crm.lead is access-restricted)
                    // instead of the raw Odoo traceback — including for a
                    // non-ApiException, whose toString() is a Dart error the
                    // user can neither read nor act on.
                    message: err is ApiException
                        ? err.localize(context)
                        : context.s.errUnknown,
                    onRetry: () => setState(() {
                      _future = widget.loader(_searchCtrl.text.isEmpty
                          ? null
                          : _searchCtrl.text);
                    }),
                  );
                }
                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return EmptyView(
                    icon: Icons.search_off_rounded,
                    message: context.s.pickerNoResults,
                  );
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) => widget.itemBuilder(ctx, items[i]),
                );
              },
            ),
          ),
          ],
        ),
      ),
    );
  }
}
