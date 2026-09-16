import 'package:flutter/services.dart';

import '../../l10n/generated/app_localizations.dart';

/// Form-field validators shared by every form, so "required" reads and trims
/// the same way on the login and server screens.
abstract final class Validators {
  /// Rejects null, empty and whitespace-only input.
  static String? required(AppLocalizations s, String? value) =>
      (value == null || value.trim().isEmpty) ? s.commonRequired : null;

  /// Blocks spaces as they are typed, for values that can never contain one
  /// (URLs, database names).
  static final noWhitespace = FilteringTextInputFormatter.deny(RegExp(r'\s'));
}
