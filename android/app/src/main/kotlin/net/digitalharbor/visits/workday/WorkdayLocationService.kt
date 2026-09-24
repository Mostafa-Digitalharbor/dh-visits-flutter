package net.digitalharbor.visits.workday

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.location.LocationRequest
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.os.Looper
import android.util.Log
import net.digitalharbor.visits.R
import org.json.JSONObject
import kotlin.math.max
import kotlin.math.min

/**
 * Captures the employee's position for the whole of an active work day.
 *
 * A `location`-type foreground service, so capture carries on when the app is
 * sent Home, another app is opened, the screen is locked, or the Flutter UI is
 * destroyed altogether — none of which a Dart timer or a Flutter-bound position
 * stream survives. The ongoing notification is the user-visible side of that:
 * it is shown for exactly as long as a work day is being captured.
 *
 * The service knows nothing about the network or the server. Each accepted fix
 * goes straight into [WorkdayStore]'s journal; Flutter moves it on from there.
 * That keeps the only work done while the UI may be gone to the part that
 * cannot be redone later — recording where the device actually was.
 *
 * Lifecycle: started by Flutter on "Start work day" (from the foreground, with
 * location permission already granted); stopped on "End work day" or logout.
 * `START_STICKY` lets the system bring it back after killing the process, and
 * it then resumes the same session from the stored config — or stops at once
 * if that config was deactivated in the meantime, so it never outlives the
 * work day.
 */
class WorkdayLocationService : Service(), LocationListener {

    companion object {
        const val ACTION_START = "net.digitalharbor.visits.workday.START"
        private const val CHANNEL_ID = "workday_tracking"
        private const val NOTIFICATION_ID = 4107
        /**
         * Requested update interval. Together with the ≥ 5 m movement rule this
         * records roughly a fix every 5 s while moving (every ~40–70 m by car,
         * every 5–10 m on foot) and nothing while standing still — dense
         * enough to reconstruct turns and the road taken, without keeping the
         * CPU awake more than the GPS itself already does. Uploads are
         * unaffected: fixes are journalled here and sent in batches by Flutter.
         */
        private const val UPDATE_INTERVAL_MS = 5_000L

        /** A fix this far from the last one is kept even inside the interval. */
        private const val BURST_DISTANCE_M = 15f

        /** Cap on the accuracy-based jitter allowance. */
        private const val MAX_JITTER_M = 15f

        /** After [STARVED_MS] without a kept fix, accept accuracy up to this. */
        private const val RELAXED_MAX_ACCURACY_M = 100f
        private const val STARVED_MS = 30_000L
        private const val TAG = "WorkdayLocation"

        /** Whether an instance is currently capturing in this process. */
        @Volatile
        var running = false
            private set
    }

    private var locationManager: LocationManager? = null
    private var subscribed = false
    private var subscribedDistance = -1f
    private var lastKept: Location? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val config = WorkdayStore.loadConfig(this)
        if (config == null) {
            // Work day already ended (or a sticky restart after it did).
            shutdown()
            return START_NOT_STICKY
        }
        try {
            enterForeground(config)
        } catch (e: Exception) {
            // e.g. location permission revoked: Android refuses a location-type
            // foreground service without it. Stop rather than crash; Flutter
            // restarts capture when the app is next opened with permission.
            Log.w(TAG, "cannot start foreground location capture: $e")
            shutdown()
            return START_NOT_STICKY
        }
        running = true
        if (subscribed && subscribedDistance != config.minDistanceMeters) {
            // Started again with different sampling rules (e.g. after an app
            // update): the OS request must be renewed to take them on.
            locationManager?.removeUpdates(this)
            subscribed = false
        }
        subscribe(config)
        return START_STICKY
    }

    private fun enterForeground(config: WorkdayStore.Config) {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                config.notificationTitle,
                NotificationManager.IMPORTANCE_LOW,
            )
            channel.setShowBadge(false)
            manager.createNotificationChannel(channel)
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        builder
            .setContentTitle(config.notificationTitle)
            .setContentText(config.notificationText)
            .setSmallIcon(R.drawable.ic_notification)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_SERVICE)
        packageManager.getLaunchIntentForPackage(packageName)?.let { launch ->
            launch.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            builder.setContentIntent(
                PendingIntent.getActivity(
                    this, 0, launch,
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                ),
            )
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        }
        val notification = builder.build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    /**
     * The fused provider where the platform has one (Android 12+), otherwise
     * GPS and network. Only one source feeds a work day: the journal would
     * otherwise interleave two providers' views of the same moment.
     */
    private fun providers(lm: LocationManager): List<String> {
        val all = lm.allProviders
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && all.contains(LocationManager.FUSED_PROVIDER)) {
            return listOf(LocationManager.FUSED_PROVIDER)
        }
        return listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER).filter { all.contains(it) }
    }

    @SuppressLint("MissingPermission")
    private fun subscribe(config: WorkdayStore.Config) {
        if (subscribed) return
        val lm = getSystemService(LOCATION_SERVICE) as LocationManager
        locationManager = lm
        for (provider in providers(lm)) {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    // Explicitly high accuracy. The legacy overload asks the fused
                    // provider for BALANCED power, which keeps satellites on only
                    // while some other request wants them — in practice while the
                    // app is in the foreground. Backgrounded, the route then stops
                    // growing wherever there is no Wi-Fi/cell positioning to fall
                    // back on.
                    val request = LocationRequest.Builder(UPDATE_INTERVAL_MS)
                        .setQuality(LocationRequest.QUALITY_HIGH_ACCURACY)
                        .setMinUpdateDistanceMeters(config.minDistanceMeters)
                        .build()
                    lm.requestLocationUpdates(provider, request, mainExecutor, this)
                } else {
                    lm.requestLocationUpdates(
                        provider,
                        UPDATE_INTERVAL_MS,
                        config.minDistanceMeters,
                        this,
                        Looper.getMainLooper(),
                    )
                }
                subscribed = true
                subscribedDistance = config.minDistanceMeters
                Log.i(TAG, "capturing work day ${config.sessionUid} from $provider " +
                    "(every ${UPDATE_INTERVAL_MS}ms, >= ${config.minDistanceMeters}m, acc <= ${config.maxAccuracyMeters}m)")
            } catch (e: SecurityException) {
                Log.w(TAG, "no location permission for $provider")
            } catch (e: IllegalArgumentException) {
                Log.w(TAG, "provider $provider unavailable")
            }
        }
        // A notification promising tracking that isn't happening would be a lie.
        if (!subscribed) shutdown()
    }

    override fun onLocationChanged(location: Location) {
        // Re-read every time: a deactivated config means the work day ended and
        // not one more fix may be recorded, even before onDestroy runs.
        val config = WorkdayStore.loadConfig(this) ?: return
        if (location.time < config.startedAtMs) return
        // After a restart (of the service or its whole process) the in-memory
        // history is gone. Continue from the last fix the journal recorded, so
        // the position the device is still sitting at is not recorded again.
        val last = lastKept ?: WorkdayStore.lastFix(this, config.sessionUid)?.also { lastKept = it }

        if (location.hasAccuracy() && location.accuracy > config.maxAccuracyMeters) {
            // Poor fixes are skipped — unless nothing better has come for a
            // while (urban canyon), when a moderately poor one beats a gap.
            val starved = last != null && location.time - last.time >= STARVED_MS
            if (!starved || location.accuracy > RELAXED_MAX_ACCURACY_M) return
        }
        if (last != null) {
            // Same or older than what is recorded: a cached position replayed
            // by the provider, typically right after a restart.
            if (location.time <= last.time) return
            val moved = last.distanceTo(location)
            // A stationary device wanders by about its accuracy; that is not
            // movement and would draw a scribble at every stop.
            val jitter = if (location.hasAccuracy()) min(location.accuracy / 2f, MAX_JITTER_M) else 0f
            if (moved < max(config.minDistanceMeters, jitter)) return
            // Updates arriving faster than the sampling interval (another app
            // asked for more) are thinned, unless they already cover real ground.
            if (location.time - last.time < config.minIntervalMs && moved < BURST_DISTANCE_M) return
        }
        lastKept = location

        val (visitId, visitSince) = WorkdayStore.visit(this)
        val fix = JSONObject()
            .put("t", location.time)
            .put("lat", location.latitude)
            .put("lng", location.longitude)
            .put("s", config.sessionUid)
        if (location.hasAccuracy()) fix.put("acc", location.accuracy.toDouble())
        if (location.hasAltitude()) fix.put("alt", location.altitude)
        if (location.hasSpeed()) fix.put("spd", location.speed.toDouble())
        if (location.hasBearing()) fix.put("hdg", location.bearing.toDouble())
        if (visitId != null && location.time >= visitSince) fix.put("v", visitId)
        try {
            val seq = WorkdayStore.append(this, fix)
            Log.i(TAG, "fix #$seq ${location.latitude},${location.longitude} visit=${visitId ?: "-"}")
        } catch (e: Exception) {
            Log.e(TAG, "journal write failed", e)
        }
    }

    // Abstract before API 30; overridden so older devices don't hit AbstractMethodError.
    override fun onProviderEnabled(provider: String) {}

    override fun onProviderDisabled(provider: String) {}

    @Deprecated("Deprecated in Android API 29")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}

    private fun shutdown() {
        locationManager?.removeUpdates(this)
        subscribed = false
        running = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onDestroy() {
        locationManager?.removeUpdates(this)
        subscribed = false
        running = false
        Log.i(TAG, "work day capture stopped")
        super.onDestroy()
    }
}
