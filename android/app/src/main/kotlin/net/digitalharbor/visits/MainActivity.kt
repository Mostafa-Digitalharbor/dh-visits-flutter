package net.digitalharbor.visits

import android.annotation.SuppressLint
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import net.digitalharbor.visits.visittracking.VisitLocationChannel
import net.digitalharbor.visits.workday.WorkdayChannel

class MainActivity : FlutterActivity() {
    // ANDROID_ID on purpose, see below; it is app-scoped and only sent hashed.
    @SuppressLint("HardwareIds")
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        VisitLocationChannel.register(this, messenger)
        WorkdayChannel.register(this, messenger)
        // The install identity behind `device_id` (lib/core/push/device_identity.dart).
        // ANDROID_ID is scoped to this app's signing key and the device user, and
        // survives a reinstall — which is what lets the server retire the token of
        // a previous install. Dart only ever sends a hash of it.
        MethodChannel(messenger, "net.digitalharbor.visits/device").setMethodCallHandler { call, result ->
            when (call.method) {
                "installId" -> result.success(
                    Settings.Secure.getString(applicationContext.contentResolver, Settings.Secure.ANDROID_ID),
                )
                else -> result.notImplemented()
            }
        }
    }
}
