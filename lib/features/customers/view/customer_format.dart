import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/constants.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../data/models/customer.dart';

/// How customer values read on screen. Shared by the list card and the detail
/// page, which each used to format coordinates their own way.
abstract final class CustomerFormat {
  /// Four decimals (~11 m) is enough to tell two offices apart on a card; the
  /// detail page shows six (~0.1 m) because users copy it into other tools.
  static final _cardCoordinate =
      NumberFormat('0.0000', AppLocales.wireFormatLocale);
  static final _preciseCoordinate =
      NumberFormat('0.000000', AppLocales.wireFormatLocale);

  /// Unicode left-to-right isolate and its terminator. A coordinate pair is
  /// "lat, lng" in both languages; in an Arabic paragraph the bidi algorithm
  /// would otherwise swap the two numbers around the comma.
  static const _ltrIsolate = '\u2066';
  static const _popIsolate = '\u2069';

  /// "24.7136, 46.6753", or null when the customer has no location.
  static String? coordinates(
    BuildContext context,
    Customer customer, {
    bool precise = false,
  }) {
    if (!customer.hasCoordinates) return null;
    final format = precise ? _preciseCoordinate : _cardCoordinate;
    final pair = context.s.commonCoordinates(
      format.format(customer.latitude),
      format.format(customer.longitude),
    );
    return '$_ltrIsolate$pair$_popIsolate';
  }

  /// Street, city/state/zip and country joined with the locale's separator;
  /// falls back to Odoo's own `contact_address` when the parts are empty.
  static String? fullAddress(BuildContext context, Customer customer) {
    final locality = [customer.city, customer.stateName, customer.zip]
        .whereType<String>()
        .join(' ');
    final parts = [customer.street, locality, customer.countryName]
        .whereType<String>()
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return customer.address;
    return parts.join(context.s.customerAddressSeparator);
  }

  /// Why a customer could not be loaded, with the next step. A missing record
  /// gets its own sentence: the generic "item not found" gives no way forward.
  static String loadFailure(BuildContext context, Object error) {
    if (error is! ApiException) return context.s.errCustomerLoadFailed;
    return error.code == ApiErrorCode.notFound
        ? context.s.customerNotFound
        : error.localize(context);
  }
}
