import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/design/app_dimens.dart';

/// Search box that waits for the user to stop typing before reporting a query.
///
/// Extracted because the customers and employees screens each carried their
/// own `Timer? _debounce` field, `dispose` cancel and identical 350ms handler —
/// a pattern that is easy to get subtly wrong (a missed `cancel()` fires a
/// query against a disposed bloc) and was drifting between the two copies.
class DebouncedSearchField extends StatefulWidget {
  final String hintText;

  /// Called with the trimmed query once [debounce] has elapsed since the last
  /// keystroke. An empty string means "cleared".
  final ValueChanged<String> onChanged;
  final Duration debounce;
  final EdgeInsetsGeometry padding;

  const DebouncedSearchField({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.debounce = AppDurations.searchDebounce,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 8),
  });

  @override
  State<DebouncedSearchField> createState() => _DebouncedSearchFieldState();
}

class _DebouncedSearchFieldState extends State<DebouncedSearchField> {
  Timer? _timer;

  @override
  void dispose() {
    // Without this a pending timer fires after the screen is gone and pushes
    // an event into a closed bloc.
    _timer?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    _timer = Timer(widget.debounce, () => widget.onChanged(value.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: TextField(
        onChanged: _onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: widget.hintText,
        ),
      ),
    );
  }
}
