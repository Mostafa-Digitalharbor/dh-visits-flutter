package net.digitalharbor.visits.visittracking

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
 * Records the GPS trail of the one customer visit that is in progress.
 *
 * A `location`-type foreground service, so the trail keeps growing when the
 * app is sent Home, another app is opened, the screen is locked, or the
 * Flutter UI is destroyed — none of which a Dart timer or a Flutter-bound
 * position stream survives. The ongoing notification is the user-visible side
 * of that: it is shown for exactly as long as a visit is being recorded.
 *
 * The service knows nothing about the network or the server. Each accepted fix
 * goes straight into [VisitLocationStore]'s journal, tagged with the visit it
 * was taken for; Flutter moves it on from there.
 *
 * Lifecycle: started by Flutter only after the server confirmed Start Visit
 * (the visit is `in_progress`), from the foreground and with location
 * permission already granted, so the while-in-use grant covers it. Stopped the
 * moment the visit is ended, and on sign-out. The config is deactivated before
 * the service is stopped, and [onLocationChanged] re-reads it for every fix,
 * so nothing is recorded after End even if an update is already queued.
 * `START_STICKY` asks the system to bring the service back after killing the
 * process; it then resumes only if the visit is still marked active, and
 * gives up quietly where the OS refuses a location service started from the
 * background — Flutter restarts capture when the app is next opened while the
 * visit is still in progress. A force-stopped app is never restarted.
 */
class VisitLocationService : Service(), LocationListener {

    companion object {
        const val ACTION_START = "net.digitalharbor.visits.visittracking.START"
        private const val CHANNEL_ID = "visit_tracking"
        private const val NOTIFICATION_ID = 4107

        /**
         * Requested update interval. Together with the movement rule this
         * records roughly a fix every 5 s while moving and nothing while
         * standing still — dense enough to reconstruct turns and the road taken
         * without keeping the CPU awake more than the GPS itself already does.
         * Uploads are unaffected: fixes are journalled here and sent in batches
         * by Flutter.
         */
        private const val UPDATE_INTERVAL_MS = 5_000L

        /** A fix this far from the last one is kept even inside the interval. */
        private const val BURST_DISTANCE_M = 15f

        /** Cap on the accuracy-based jitter allowance. */
        private const val MAX_JITTER_M = 15f

        /** After [STARVED_MS] without a kept fix, accept accuracy up to this. */
        private const val RELAXED_MAX_ACCURACY_M = 100f
        private const val STARVED_MS = 30_000L
        private const val TAG = "VisitLocation"

        /** Whether an instance is currently capturing in this process. */
        @Volatile
        var running = false
            private set
    }

    private var locationManager: LocationManager? = null
    private var subscribed = false
    private var subscribedDistance = -1f
    private var lastKept: Location? = null
    private var lastKeptVisit: Long? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val config = VisitLocationStore.loadConfig(this)
        if (config == null) {
            // The visit already ended (or this is a sticky restart after it did).
            shutdown()
            return START_NOT_STICKY
        }
        try {
            enterForeground(config)
        } catch (e: Exception) {
            // Location permission revoked, or a sticky restart from the
            // background that the OS does not allow for a location service.
            // Stop rather than crash; Flutter restarts capture when the app is
            // next opened while the visit is still in progress.
            Log.w(TAG, "cannot start foreground location capture: $e")
            shutdown()
            return START_NOT_STICKY
        }
        running = true
        if (lastKeptVisit != config.visitId) {
            lastKept = null
            lastKeptVisit = config.visitId
        }
        if (subscribed && subscribedDistance != config.minDistanceMeters) {
            // Started again with different sampling rules (e.g. after an app
            // update): the OS request must be renewed to take them on.
            locationManager?.removeUpdates(this)
            subscribed = false
        }
        subscribe(config)
        return START_STICKY
    }

    private fun enterForeground(config: VisitLocationStore.Config) {
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
     * GPS and network. Only one source feeds a trail: the journal would
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
    private fun subscribe(config: VisitLocationStore.Config) {
        if (subscribed) return
        val lm = getSystemService(LOCATION_SERVICE) as LocationManager
        locationManager = lm
        for (provider in providers(lm)) {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    // Explicitly high accuracy. The legacy overload asks the fused
                    // provider for BALANCED power, which keeps satellites on only
                    // while some other request wants them — in practice while the
                    // app is in the foreground. Backgrounded, the trail then stops
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
                Log.i(TAG, "recording visit ${config.visitId} from $provider " +
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
        // Re-read every time: a deactivated config means the visit ended and not
        // one more fix may be recorded, even before onDestroy runs.
        val config = VisitLocationStore.loadConfig(this)
        if (config == null) {
            shutdown()
            return
        }
        // Cached positions the provider replays when the subscription opens
        // predate the visit's start; the server would refuse them anyway.
        if (location.time < config.startedAtMs) return
        if (lastKeptVisit != config.visitId) {
            lastKept = null
            lastKeptVisit = config.visitId
        }
        // After a restart (of the service or its whole process) the in-memory
        // history is gone. Continue from the last fix the journal recorded, so
        // the position the device is still sitting at is not recorded again.
        val last = lastKept ?: VisitLocationStore.lastFix(this, config.visitId)?.also { lastKept = it }

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

        val fix = JSONObject()
            .put("t", location.time)
            .put("lat", location.latitude)
            .put("lng", location.longitude)
            .put("v", config.visitId)
        if (location.hasAccuracy()) fix.put("acc", location.accuracy.toDouble())
        if (location.hasAltitude()) fix.put("alt", location.altitude)
        if (location.hasSpeed()) fix.put("spd", location.speed.toDouble())
        if (location.hasBearing()) fix.put("hdg", location.bearing.toDouble())
        try {
            val seq = VisitLocationStore.append(this, fix)
            Log.i(TAG, "fix #$seq recorded for visit ${config.visitId}")
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
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        locationManager?.removeUpdates(this)
        subscribed = false
        running = false
        Log.i(TAG, "visit capture stopped")
        super.onDestroy()
    }
}
