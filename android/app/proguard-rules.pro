# Flutter / Dart wrapper classes accessed via JNI.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.embedding.** { *; }

# flutter_secure_storage uses Android Keystore via reflection on some OEMs.
-keep class androidx.security.crypto.** { *; }

# geolocator / permission_handler — keep callbacks reachable from native.
-keep class com.baseflow.** { *; }

# Don't warn about missing optional dependencies.
-dontwarn io.flutter.embedding.**
-dontwarn com.google.android.play.core.**

# Keep Kotlin metadata for libraries that use it at runtime.
-keep class kotlin.Metadata { *; }
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
