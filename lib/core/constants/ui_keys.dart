import 'package:flutter/widgets.dart';

/// Hero tags. Two heroes with the same tag on one route crash the transition,
/// so every tag is declared once here instead of typed at the call site.
abstract final class HeroTags {
  static const createVisitUser = 'create-visit-user-hero';
  static const createVisitManager = 'create-visit-hero';
}

/// Widget keys that tests and UI automation address.
abstract final class WidgetKeys {
  static const visitTrackingDisclosureAgree =
      Key('visit-tracking-disclosure-agree');
  static const visitTrackingDisclosureDecline =
      Key('visit-tracking-disclosure-decline');
  static const workdayDisclosureAgree = Key('workday-disclosure-agree');
  static const workdayDisclosureDecline = Key('workday-disclosure-decline');

  // AsyncListView's cross-fade children.
  static const listSkeleton = ValueKey('skeleton');
  static const listEmpty = ValueKey('empty');
  static const listContent = ValueKey('list');
}
