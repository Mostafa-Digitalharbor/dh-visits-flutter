// app_assets.dart — single source of truth for bundled asset paths.
//
// Never hard-code an `assets/...` string in a widget: reference [AppAssets]
// so a renamed/moved file is fixed in exactly one place and typos surface at
// compile time instead of as a blank image at runtime.
class AppAssets {
  AppAssets._();

  static const String _images = 'assets/images';

  /// Full-color brand logo (used for launcher icon source & splash).
  static const String logo = '$_images/logo.jpg';

  /// White/mono "D" mark used on dark surfaces (top bar, auth chrome).
  static const String logoMarkD = '$_images/logo-d.png';

  /// Standalone logomark.
  static const String logoMark = '$_images/logomark.png';

  /// Decorative Cairo map backdrop on the auth screens.
  static const String mapCairo = '$_images/map-cairo.png';
}
