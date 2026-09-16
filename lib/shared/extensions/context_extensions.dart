import 'package:flutter/material.dart';

import '../../core/api/api_exceptions.dart';
import '../../core/api/api_error_messages.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../app/design/app_dimens.dart';
import '../../app/design/responsive.dart';
import '../../app/theme.dart' show AppX;

/// Visual kind for snackbars — drives the leading icon and accent color
/// on `context.showSnack`. Defaults to `info` for plain messages and
/// switches to `success` / `error` for explicit results.
enum SnackKind { info, success, error }

extension AppContext on BuildContext {
  AppLocalizations get s => AppLocalizations.of(this);
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isRtl => Directionality.of(this) == TextDirection.rtl;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Joins the non-empty [parts] with the localized list separator —
  /// "VIS/0012 · Project Alpha". Null and blank parts are skipped, so a line
  /// never starts or ends with a dangling separator.
  String joinFacts(Iterable<String?> parts) => parts
      .whereType<String>()
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .join(s.commonListSeparator);

  /// Runs an external-launch action (dial / mail / maps) and, if it fails
  /// (no handler app, or the launch threw), shows a clear localized message
  /// instead of the tap silently doing nothing.
  Future<void> openExternal(Future<bool> Function() launch) async {
    bool ok;
    try {
      ok = await launch();
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) {
      showSnack(s.errCannotLaunchApp, kind: SnackKind.error);
    }
  }

  /// Shows [message] as the app's floating snackbar.
  ///
  /// An info or success message replaces whatever is showing — it is only
  /// news. An error waits its turn instead: several offline actions refused in
  /// one sync each deserve to be read, and replacing one with the next hid all
  /// but the last. Errors also stay longer and can be dismissed by hand.
  void showSnack(String message, {SnackKind kind = SnackKind.info}) {
    final scheme = colors;
    final x = Theme.of(this).extension<AppX>();
    final isError = kind == SnackKind.error;
    final (icon, bg, fg) = switch (kind) {
      // The container pair, not white on green: white on the brand green
      // falls below the contrast a 14sp label needs.
      SnackKind.success => (
          Icons.check_circle_rounded,
          x?.successContainer ?? scheme.primaryContainer,
          x?.onSuccessContainer ?? scheme.onPrimaryContainer,
        ),
      SnackKind.error => (
          Icons.error_outline_rounded,
          scheme.error,
          scheme.onError,
        ),
      SnackKind.info => (
          Icons.info_outline_rounded,
          scheme.inverseSurface,
          scheme.onInverseSurface,
        ),
    };
    final messenger = ScaffoldMessenger.of(this);
    if (!isError) messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsetsDirectional.fromSTEB(
        r(Insets.x4),
        r(Insets.x3),
        r(Insets.x4),
        r(Insets.x4),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.btn),
      ),
      elevation: _snackElevation,
      duration: isError ? AppDurations.snackError : AppDurations.snack,
      showCloseIcon: isError,
      closeIconColor: fg,
      content: Row(
        children: [
          Icon(icon, color: fg, size: IconSz.sm),
          // Unqualified: inside an extension on BuildContext the receiver
          // *is* the context, and the sibling Responsive extension hangs off
          // the same type.
          gapW(Insets.x2h),
          Expanded(
            child: Text(
              message,
              maxLines: _snackMaxLines,
              overflow: TextOverflow.ellipsis,
              style: text.bodyMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ));
  }
}

/// Lift of the floating snackbar above the page.
const double _snackElevation = 4;

/// Enough for the longest localized error sentence at the largest text scale;
/// anything longer is a server message that must not cover the screen.
const int _snackMaxLines = 5;

extension ApiExceptionL10n on ApiException {
  /// The sentence the user reads for this failure, in the UI's language.
  /// See [ApiErrorMessages.messageFor] for the mapping itself.
  String localize(BuildContext context) => messageFor(context.s);
}
