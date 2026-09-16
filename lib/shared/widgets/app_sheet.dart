import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../extensions/context_extensions.dart';

/// Opens the app's modal bottom sheet: surface background, rounded top,
/// safe-area aware, lifted above the keyboard, width-bounded on tablets.
///
/// [builder] receives the sheet's context. Pop it with a value to return one.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.colors.surface,
    constraints: const BoxConstraints(maxWidth: CompSz.dialogMaxWidth),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
    ),
    builder: builder,
  );
}

/// A form sheet: title row with a close button, then [child], all scrollable
/// and lifted by the keyboard inset.
///
/// Scrollable because every form body autofocuses: on a short viewport the
/// title, a multiline field and the submit button exceed the space above the
/// keyboard, and an unscrollable column would overflow and hide the action.
class AppFormSheet extends StatelessWidget {
  final String title;
  final Widget child;

  const AppFormSheet({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.keyboardInset),
      child: SingleChildScrollView(
        padding: context.padAll(Insets.x4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSheetHeader(title: title),
            context.gapH(Insets.x2),
            child,
          ],
        ),
      ),
    );
  }
}

/// A sheet's title with a close button at the end.
class AppSheetHeader extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry padding;

  const AppSheetHeader({
    super.key,
    required this.title,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: context.s.commonClose,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}
