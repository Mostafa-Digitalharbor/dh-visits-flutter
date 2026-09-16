import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load signing config from key.properties (kept out of git).
// Template: android/key.properties.template
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "net.digitalharbor.visits"
    // 36 is required by androidx.browser:1.9.0 / androidx.core:1.17.0 pulled in
    // by url_launcher and other plugins. Bumping compileSdk alone is safe — it
    // does NOT change runtime behaviour (that's targetSdk).
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Required by flutter_local_notifications (uses java.time APIs that need
        // backporting on minSdk 23). Pair with the desugar_jdk_libs dependency
        // in the dependencies block below.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "net.digitalharbor.visits"
        // 23 = Android 6.0 Marshmallow. Required by flutter_secure_storage
        // (uses AndroidKeyStore APIs added in M) and permission_handler runtime
        // permission flow.
        minSdk = flutter.minSdkVersion
        // 36 = Android 16. Google Play requires new apps and app updates to
        // target API 36 from 31 Aug 2026 (developer.android.com/google/play/
        // requirements/target-sdk). compileSdk must be >= targetSdk. Targeting
        // 36 enables predictive back by default (PopScope/go_router handle it)
        // and keeps edge-to-edge enforced (already the case since 35).
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            // Fall back to debug signing only when key.properties is missing
            // (e.g. for `flutter run --release` during development).
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            applicationIdSuffix = ".debug"
            isMinifyEnabled = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Backports java.time (and friends) so flutter_local_notifications works on
    // API levels below 26. Version must be >= what the plugin requires.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
