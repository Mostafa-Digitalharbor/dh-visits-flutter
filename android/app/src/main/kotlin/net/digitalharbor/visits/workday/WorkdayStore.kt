package net.digitalharbor.visits.workday

import android.content.Context
import android.content.SharedPreferences
import android.location.Location
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream

/**
 * On-device state of the work-day location capture, shared by
 * [WorkdayLocationService] (the writer) and [WorkdayChannel] (the reader that
 * hands fixes to Flutter).
 *
 * Two pieces:
 *
 * - **Config** (SharedPreferences): whether a work day is being captured, for
 *   which local session, with which sampling rules, and which visit (if any) is
 *   running. The service re-reads it on every fix, so turning `active` off
 *   stops capture immediately even before the service has been torn down, and
 *   a service restarted by the system after its process was killed picks the
 *   same session back up.
 * - **Journal** (an append-only JSON-lines file in the app's private files
 *   directory): every accepted fix is written and fsync'd the moment it
 *   arrives, before anything depends on the network or on a Flutter engine
 *   being alive. Flutter reads the journal, moves the fixes into its upload
 *   queue, and acknowledges them by sequence number, which removes them here.
 *
 * All journal access is serialised on one lock: the service appends from the
 * main looper while the channel reads and truncates from platform calls.
 */
internal object WorkdayStore {
    private const val PREFS = "workday_location_capture"
    private const val JOURNAL = "workday_fixes.jsonl"

    private const val K_ACTIVE = "active"
    private const val K_SESSION = "session_uid"
    private const val K_MIN_DISTANCE = "min_distance_m"
    private const val K_MIN_INTERVAL = "min_interval_ms"
    private const val K_MAX_ACCURACY = "max_accuracy_m"
    private const val K_STARTED_AT = "started_at_ms"
    private const val K_TITLE = "notification_title"
    private const val K_TEXT = "notification_text"
    private const val K_VISIT = "visit_id"
    private const val K_VISIT_SINCE = "visit_since_ms"
    private const val K_SEQ = "seq"
    private const val K_LAST_SESSION = "last_fix_session"
    private const val K_LAST_T = "last_fix_t"
    private const val K_LAST_LAT = "last_fix_lat"
    private const val K_LAST_LNG = "last_fix_lng"

    private val lock = Any()

    data class Config(
        val sessionUid: String,
        val minDistanceMeters: Float,
        val minIntervalMs: Long,
        val maxAccuracyMeters: Float,
        /** Fixes stamped before this are cached positions replayed by the OS. */
        val startedAtMs: Long,
        val notificationTitle: String,
        val notificationText: String,
    )

    private fun prefs(ctx: Context): SharedPreferences =
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /**
     * [seedLatitude]/[seedLongitude]: the work day's start position. When
     * capture begins for a session with no recorded fix yet, it becomes the
     * "last recorded fix", so the first update at the start position isn't
     * recorded a second time. A session that already has fixes keeps its own.
     */
    fun saveConfig(
        ctx: Context,
        config: Config,
        visitId: Long?,
        visitSinceMs: Long,
        seedLatitude: Double? = null,
        seedLongitude: Double? = null,
    ) {
        val p = prefs(ctx)
        val e = p.edit()
        if (p.getString(K_LAST_SESSION, null) != config.sessionUid) {
            if (seedLatitude != null && seedLongitude != null) {
                e.putString(K_LAST_SESSION, config.sessionUid)
                    .putLong(K_LAST_T, config.startedAtMs)
                    .putString(K_LAST_LAT, seedLatitude.toString())
                    .putString(K_LAST_LNG, seedLongitude.toString())
            } else {
                e.remove(K_LAST_SESSION).remove(K_LAST_T).remove(K_LAST_LAT).remove(K_LAST_LNG)
            }
        }
        e
            .putBoolean(K_ACTIVE, true)
            .putString(K_SESSION, config.sessionUid)
            .putFloat(K_MIN_DISTANCE, config.minDistanceMeters)
            .putLong(K_MIN_INTERVAL, config.minIntervalMs)
            .putFloat(K_MAX_ACCURACY, config.maxAccuracyMeters)
            .putLong(K_STARTED_AT, config.startedAtMs)
            .putString(K_TITLE, config.notificationTitle)
            .putString(K_TEXT, config.notificationText)
            .putLong(K_VISIT_SINCE, visitSinceMs)
        if (visitId != null) e.putLong(K_VISIT, visitId) else e.remove(K_VISIT)
        e.commit()
    }

    /** The active capture config, or null when no work day is being captured. */
    fun loadConfig(ctx: Context): Config? {
        val p = prefs(ctx)
        if (!p.getBoolean(K_ACTIVE, false)) return null
        val session = p.getString(K_SESSION, null) ?: return null
        return Config(
            sessionUid = session,
            minDistanceMeters = p.getFloat(K_MIN_DISTANCE, 5f),
            minIntervalMs = p.getLong(K_MIN_INTERVAL, 4_000L),
            maxAccuracyMeters = p.getFloat(K_MAX_ACCURACY, 50f),
            startedAtMs = p.getLong(K_STARTED_AT, 0L),
            notificationTitle = p.getString(K_TITLE, null) ?: "",
            notificationText = p.getString(K_TEXT, null) ?: "",
        )
    }

    fun isActive(ctx: Context): Boolean = prefs(ctx).getBoolean(K_ACTIVE, false)

    /** Ends capture. Committed synchronously, so a fix arriving afterwards is ignored. */
    fun deactivate(ctx: Context) {
        prefs(ctx).edit().putBoolean(K_ACTIVE, false).remove(K_VISIT).commit()
    }

    fun setVisit(ctx: Context, visitId: Long?, sinceMs: Long) {
        val e = prefs(ctx).edit().putLong(K_VISIT_SINCE, sinceMs)
        if (visitId != null) e.putLong(K_VISIT, visitId) else e.remove(K_VISIT)
        e.commit()
    }

    /** The running visit and the device time from which fixes belong to it. */
    fun visit(ctx: Context): Pair<Long?, Long> {
        val p = prefs(ctx)
        val id = if (p.contains(K_VISIT)) p.getLong(K_VISIT, 0L) else null
        return id to p.getLong(K_VISIT_SINCE, 0L)
    }

    /**
     * The last fix recorded for [sessionUid] (or its seeded start position),
     * surviving a restart of the service or its process.
     */
    fun lastFix(ctx: Context, sessionUid: String): Location? {
        val p = prefs(ctx)
        if (p.getString(K_LAST_SESSION, null) != sessionUid) return null
        val lat = p.getString(K_LAST_LAT, null)?.toDoubleOrNull() ?: return null
        val lng = p.getString(K_LAST_LNG, null)?.toDoubleOrNull() ?: return null
        return Location("journal").apply {
            latitude = lat
            longitude = lng
            time = p.getLong(K_LAST_T, 0L)
        }
    }

    /** Appends one fix, assigning it the next sequence number. */
    fun append(ctx: Context, fix: JSONObject): Long = synchronized(lock) {
        val p = prefs(ctx)
        val seq = p.getLong(K_SEQ, 0L) + 1
        p.edit()
            .putLong(K_SEQ, seq)
            .putString(K_LAST_SESSION, fix.getString("s"))
            .putLong(K_LAST_T, fix.getLong("t"))
            .putString(K_LAST_LAT, fix.getDouble("lat").toString())
            .putString(K_LAST_LNG, fix.getDouble("lng").toString())
            .commit()
        fix.put("seq", seq)
        FileOutputStream(File(ctx.filesDir, JOURNAL), true).use { out ->
            out.write((fix.toString() + "\n").toByteArray(Charsets.UTF_8))
            out.fd.sync()
        }
        seq
    }

    /** Up to [max] journalled fixes, oldest first. */
    fun read(ctx: Context, max: Int): List<Map<String, Any?>> = synchronized(lock) {
        val file = File(ctx.filesDir, JOURNAL)
        if (!file.exists()) return emptyList()
        val out = ArrayList<Map<String, Any?>>()
        file.bufferedReader(Charsets.UTF_8).useLines { lines ->
            for (line in lines) {
                if (out.size >= max) break
                if (line.isBlank()) continue
                // A line torn by a crash mid-write is skipped, not fatal.
                try {
                    out.add(toMap(JSONObject(line)))
                } catch (_: Exception) {
                }
            }
        }
        out
    }

    /** Removes every fix with a sequence number up to and including [seq]. */
    fun ackThrough(ctx: Context, seq: Long) {
        synchronized(lock) {
            val file = File(ctx.filesDir, JOURNAL)
            if (!file.exists()) return
            val keep = ArrayList<String>()
            file.bufferedReader(Charsets.UTF_8).useLines { lines ->
                for (line in lines) {
                    if (line.isBlank()) continue
                    val s = try {
                        JSONObject(line).optLong("seq", 0L)
                    } catch (_: Exception) {
                        0L
                    }
                    if (s > seq) keep.add(line)
                }
            }
            if (keep.isEmpty()) {
                file.delete()
                return
            }
            val tmp = File(ctx.filesDir, "$JOURNAL.tmp")
            FileOutputStream(tmp).use { out ->
                for (l in keep) out.write((l + "\n").toByteArray(Charsets.UTF_8))
                out.fd.sync()
            }
            if (!tmp.renameTo(file)) {
                file.delete()
                tmp.renameTo(file)
            }
        }
    }

    private fun toMap(o: JSONObject): Map<String, Any?> {
        fun optDouble(key: String): Double? = if (o.has(key)) o.getDouble(key) else null
        return mapOf(
            "seq" to o.optLong("seq", 0L),
            "t" to o.getLong("t"),
            "lat" to o.getDouble("lat"),
            "lng" to o.getDouble("lng"),
            "acc" to optDouble("acc"),
            "alt" to optDouble("alt"),
            "spd" to optDouble("spd"),
            "hdg" to optDouble("hdg"),
            "s" to o.getString("s"),
            "v" to if (o.has("v")) o.getLong("v") else null,
        )
    }
}
