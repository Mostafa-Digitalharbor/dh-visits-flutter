package net.digitalharbor.visits.workday

import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter's handle on the work-day capture: start/stop the foreground service,
 * tell it which visit is running, and drain its journal.
 * Dart side: `lib/core/location/workday_location_channel.dart`.
 */
object WorkdayChannel {
    private const val NAME = "net.digitalharbor.visits/workday_location"

    fun register(context: Context, messenger: BinaryMessenger) {
        val app = context.applicationContext
        MethodChannel(messenger, NAME).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "start" -> {
                        val config = WorkdayStore.Config(
                            sessionUid = call.argument<String>("sessionUid")
                                ?: throw IllegalArgumentException("sessionUid is required"),
                            minDistanceMeters = (call.argument<Number>("minDistanceMeters") ?: 5).toFloat(),
                            minIntervalMs = (call.argument<Number>("minIntervalMs") ?: 4_000).toLong(),
                            maxAccuracyMeters = (call.argument<Number>("maxAccuracyMeters") ?: 50).toFloat(),
                            startedAtMs = (call.argument<Number>("startedAtMs") ?: System.currentTimeMillis()).toLong(),
                            notificationTitle = call.argument<String>("title") ?: "",
                            notificationText = call.argument<String>("text") ?: "",
                        )
                        WorkdayStore.saveConfig(
                            app,
                            config,
                            call.argument<Number>("visitId")?.toLong(),
                            (call.argument<Number>("visitSinceMs") ?: System.currentTimeMillis()).toLong(),
                            call.argument<Number>("seedLatitude")?.toDouble(),
                            call.argument<Number>("seedLongitude")?.toDouble(),
                        )
                        val intent = Intent(app, WorkdayLocationService::class.java)
                            .setAction(WorkdayLocationService.ACTION_START)
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
                        WorkdayStore.deactivate(app)
                        app.stopService(Intent(app, WorkdayLocationService::class.java))
                        result.success(true)
                    }
                    "setVisit" -> {
                        WorkdayStore.setVisit(
                            app,
                            call.argument<Number>("visitId")?.toLong(),
                            (call.argument<Number>("sinceMs") ?: System.currentTimeMillis()).toLong(),
                        )
                        result.success(true)
                    }
                    "status" -> result.success(
                        mapOf(
                            "active" to WorkdayStore.isActive(app),
                            "running" to WorkdayLocationService.running,
                        ),
                    )
                    "read" -> result.success(
                        WorkdayStore.read(app, (call.argument<Number>("max") ?: 500).toInt()),
                    )
                    "ack" -> {
                        val seq = call.argument<Number>("throughSeq")
                            ?: throw IllegalArgumentException("throughSeq is required")
                        WorkdayStore.ackThrough(app, seq.toLong())
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("workday_location", e.message, null)
            }
        }
    }
}
