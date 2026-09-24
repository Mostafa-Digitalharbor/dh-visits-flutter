package net.digitalharbor.visits.visittracking

import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter's handle on the visit trail capture: start/stop the foreground
 * service for one visit and drain its journal.
 * Dart side: `lib/core/location/visit_location_channel.dart`.
 */
object VisitLocationChannel {
    private const val NAME = "net.digitalharbor.visits/visit_location"

    fun register(context: Context, messenger: BinaryMessenger) {
        val app = context.applicationContext
        MethodChannel(messenger, NAME).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "start" -> {
                        val visitId = call.argument<Number>("visitId")?.toLong()
                            ?: throw IllegalArgumentException("visitId is required")
                        val config = VisitLocationStore.Config(
                            visitId = visitId,
                            startedAtMs = (call.argument<Number>("sinceMs") ?: System.currentTimeMillis()).toLong(),
                            minDistanceMeters = (call.argument<Number>("minDistanceMeters") ?: 10).toFloat(),
                            minIntervalMs = (call.argument<Number>("minIntervalMs") ?: 4_000).toLong(),
                            maxAccuracyMeters = (call.argument<Number>("maxAccuracyMeters") ?: 50).toFloat(),
                            notificationTitle = call.argument<String>("title") ?: "",
                            notificationText = call.argument<String>("text") ?: "",
                        )
                        VisitLocationStore.saveConfig(
                            app,
                            config,
                            call.argument<Number>("seedLatitude")?.toDouble(),
                            call.argument<Number>("seedLongitude")?.toDouble(),
                        )
                        val intent = Intent(app, VisitLocationService::class.java)
                            .setAction(VisitLocationService.ACTION_START)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            app.startForegroundService(intent)
                        } else {
                            app.startService(intent)
                        }
                        result.success(true)
                    }
                    "stop" -> {
                        // Deactivate first (synchronously): the service ignores any fix
                        // that lands between this call and its own teardown.
                        VisitLocationStore.deactivate(app)
                        app.stopService(Intent(app, VisitLocationService::class.java))
                        result.success(true)
                    }
                    "status" -> {
                        val config = VisitLocationStore.loadConfig(app)
                        result.success(
                            mapOf(
                                "active" to (config != null),
                                "running" to VisitLocationService.running,
                                "visitId" to config?.visitId,
                            ),
                        )
                    }
                    "read" -> result.success(
                        VisitLocationStore.read(app, (call.argument<Number>("max") ?: 500).toInt()),
                    )
                    "ack" -> {
                        val seq = call.argument<Number>("throughSeq")
                            ?: throw IllegalArgumentException("throughSeq is required")
                        VisitLocationStore.ackThrough(app, seq.toLong())
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("visit_location", e.message, null)
            }
        }
    }
}
