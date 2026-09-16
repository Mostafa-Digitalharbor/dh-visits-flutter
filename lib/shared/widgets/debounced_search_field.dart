import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/design/app_dimens.dart';
import '../../app/design/responsive.dart';

/// Search box that waits for the user to stop typing before reporting a query.
///
/// Extracted because the customers and employees screens (and the picker
/// sheet) each carried their own `Timer? _debounce`, `dispose` cancel and
/// handler — a pattern that is easy to get subtly wrong (a missed `cancel()`
/// fires a query against a disposed bloc) and was drifting between copies.
class DebouncedSearchField extends StatefulWidget {
  final String hintText;

  /// Called with the trimmed query once [debounce] has elapsed since the last
  /// keystroke, or at once when the field is cleared (with `''`).
  final ValueChanged<String> onChanged;
  final Duration debounce;

  /// Design-space padding around the field; scaled with the device.
  final EdgeInsetsGeometry padding;

  /// Optional: lets the owner read the current text (to repeat a search).
  final TextEditingController? controller;

  const DebouncedSearchField({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.debounce = AppDurations.searchDebounce,
    this.controller,
    this.padding = const EdgeInsetsDirectional.fromSTEB(
      Insets.x4,
      Insets.x3,
      Insets.x4,
      Insets.x2,
    ),
  });

  @override
  State<DebouncedSearchField> createState() => _DebouncedSearchFieldState();
}

class _DebouncedSearchFieldState extends State<DebouncedSearchField> {
  Timer? _timer;
  TextEditingController? _ownController;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());

  @override
  void dispose() {
    // Without this a pending timer fires after the screen is gone and pushes
    // an event into a closed bloc.
    _timer?.cancel();
    _ownController?.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    _timer = Timer(widget.debounce, () => widget.onChanged(value.trim()));
  }

  void _clear() {
    _timer?.cancel();
    _controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.padding.resolve(Directionality.of(context));
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.r(p.left),
        context.rh(p.top),
        context.r(p.right),
        context.rh(p.bottom),
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _controller,
        builder: (context, value, _) => TextField(
          controller: _controller,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: widget.hintText,
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    tooltip:
                        MaterialLocalizations.of(context).clearButtonTooltip,
                    onPressed: _clear,
                  ),
          ),
        ),
      ),
    );
  }
}
