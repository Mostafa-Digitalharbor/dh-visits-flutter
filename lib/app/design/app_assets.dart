// app_assets.dart — single source of truth for bundled asset paths.
//
// Never hard-code an `assets/...` string in a widget: reference [AppAssets]
// so a renamed/moved file is fixed in exactly one place and typos surface at
// compile time instead of as a blank image at runtime.
class AppAssets {
  AppAssets._();

  static const String _images = 'assets/images';

  /// Full brand logo — artwork on its own navy plate, rounded corners already
  /// baked in. Use where the logo stands alone on an arbitrary background.
  static const String logo = '$_images/visit-logo.png';

  /// The logo artwork with the navy plate removed. Use when the logo sits on a
  /// surface that already supplies its own shape (a white circle/tile), or when
  /// it is flattened to a single colour via `Image.asset(..., color: ...)`.
  static const String logoMark = '$_images/visit-logo-mark.png';

  /// Decorative Cairo map backdrop on the auth screens.
  static const String mapCairo = '$_images/map-cairo.png';

  /// Android status-bar icon for notifications.
  ///
  /// Not an `assets/` bundle path — it resolves against `android/app/src/main/
  /// res/drawable-*`. It lives here anyway because it is referenced from two
  /// places in the push service, and renaming the drawable without updating
  /// both silently leaves notifications iconless.
  ///
  /// This must stay a dedicated white-on-transparent silhouette and must NOT be
  /// pointed back at `@mipmap/ic_launcher`: Android discards the small icon's
  /// colour channels and keeps only its alpha, so a full-bleed launcher icon
  /// renders as an opaque blob. Regenerate via `tool/generate_icons.ps1`.
  /// The full-colour logo reaches the notification as the *large* icon instead
  /// (see [PushNotificationService]) and via the manifest's
  /// `default_notification_color` accent.
  static const String androidNotificationIcon = '@drawable/ic_notification';

  /// Android launcher icon, used as a foreground notification's full-colour
  /// large icon. Resolves against `android/app/src/main/res/mipmap-*`.
  static const String androidLauncherIcon = '@mipmap/ic_launcher';
}
