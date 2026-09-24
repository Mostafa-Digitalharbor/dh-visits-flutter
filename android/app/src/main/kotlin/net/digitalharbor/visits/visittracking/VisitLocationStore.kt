package net.digitalharbor.visits.visittracking

import android.annotation.SuppressLint
import android.content.Context
import android.content.SharedPreferences
import android.location.Location
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream

/**
 * On-device state of the visit location capture, shared by
 * [VisitLocationService] (the writer) and [VisitLocationChannel] (the reader
 * that hands fixes to Flutter).
 *
 * Two pieces:
 *
 * - **Config** (SharedPreferences): whether a visit is being captured, which
 *   one, from when, and with which sampling rules. The service re-reads it on
 *   every fix, so deactivating it stops capture immediately — even before the
 *   service has been torn down — and a service the system restarts after
 *   killing the process only carries on while the visit is still marked
 *   active.
 * - **Journal** (an append-only JSON-lines file in the app's private files
 *   directory): every accepted fix is written and fsync'd the moment it
 *   arrives, before anything depends on the network or on a Flutter engine
 *   being alive. Flutter reads the journal, moves the fixes into its upload
 *   buffer, and acknowledges them by sequence number, which removes them here.
 *
 * All journal access is serialised on one lock: the service appends from the
 * main looper while the channel reads and truncates from platform calls.
 */
// commit(), not apply(): the config and the sequence counter must be on disk
// before the caller moves on — deactivation before the service is stopped, the
// counter before its journal line is written.
@SuppressLint("ApplySharedPref")
internal object VisitLocationStore {
    private const val PREFS = "visit_location_capture"
    private const val JOURNAL = "visit_fixes.jsonl"

    private const val K_ACTIVE = "active"
    private const val K_VISIT = "visit_id"
    private const val K_STARTED_AT = "started_at_ms"
    private const val K_MIN_DISTANCE = "min_distance_m"
    private const val K_MIN_INTERVAL = "min_interval_ms"
    private const val K_MAX_ACCURACY = "max_accuracy_m"
    private const val K_TITLE = "notification_title"
    private const val K_TEXT = "notification_text"
    private const val K_SEQ = "seq"
    private const val K_LAST_VISIT = "last_fix_visit"
    private const val K_LAST_T = "last_fix_t"
    private const val K_LAST_LAT = "last_fix_lat"
    private const val K_LAST_LNG = "last_fix_lng"

    private val lock = Any()

    data class Config(
        val visitId: Long,
        /** Fixes stamped before this are cached positions replayed by the OS. */
        val startedAtMs: Long,
        val minDistanceMeters: Float,
        val minIntervalMs: Long,
        val maxAccuracyMeters: Float,
        val notificationTitle: String,
        val notificationText: String,
    )

    private fun prefs(ctx: Context): SharedPreferences =
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /**
     * Marks [config]'s visit as captured. [seedLatitude]/[seedLongitude] is
     * the visit's start position: when capture begins for a visit with no
     * recorded fix yet, it becomes the "last recorded fix", so the first
     * update at the start spot isn't recorded a second time (the start action
     * already put it on the trail). A visit that already has fixes keeps its
     * own.
     */
    fun saveConfig(
        ctx: Context,
        config: Config,
        seedLatitude: Double? = null,
        seedLongitude: Double? = null,
    ) {
        val p = prefs(ctx)
        val e = p.edit()
        if (!p.contains(K_LAST_VISIT) || p.getLong(K_LAST_VISIT, 0L) != config.visitId) {
            if (seedLatitude != null && seedLongitude != null) {
                e.putLong(K_LAST_VISIT, config.visitId)
                    .putLong(K_LAST_T, config.startedAtMs)
                    .putString(K_LAST_LAT, seedLatitude.toString())
                    .putString(K_LAST_LNG, seedLongitude.toString())
            } else {
                e.remove(K_LAST_VISIT).remove(K_LAST_T).remove(K_LAST_LAT).remove(K_LAST_LNG)
            }
        }
        e
            .putBoolean(K_ACTIVE, true)
            .putLong(K_VISIT, config.visitId)
            .putLong(K_STARTED_AT, config.startedAtMs)
            .putFloat(K_MIN_DISTANCE, config.minDistanceMeters)
            .putLong(K_MIN_INTERVAL, config.minIntervalMs)
            .putFloat(K_MAX_ACCURACY, config.maxAccuracyMeters)
            .putString(K_TITLE, config.notificationTitle)
            .putString(K_TEXT, config.notificationText)
            .commit()
    }

    /** The active capture config, or null when no visit is being captured. */
    fun loadConfig(ctx: Context): Config? {
        val p = prefs(ctx)
        if (!p.getBoolean(K_ACTIVE, false) || !p.contains(K_VISIT)) return null
        return Config(
            visitId = p.getLong(K_VISIT, 0L),
            startedAtMs = p.getLong(K_STARTED_AT, 0L),
            minDistanceMeters = p.getFloat(K_MIN_DISTANCE, 10f),
            minIntervalMs = p.getLong(K_MIN_INTERVAL, 4_000L),
            maxAccuracyMeters = p.getFloat(K_MAX_ACCURACY, 50f),
            notificationTitle = p.getString(K_TITLE, null) ?: "",
            notificationText = p.getString(K_TEXT, null) ?: "",
        )
    }

    /**
     * Ends capture. Committed synchronously, so a fix delivered afterwards —
     * even one already queued on the looper — is ignored.
     */
    fun deactivate(ctx: Context) {
        prefs(ctx).edit().putBoolean(K_ACTIVE, false).remove(K_VISIT).commit()
    }

    /**
     * The last fix recorded for [visitId] (or its seeded start position),
     * surviving a restart of the service or its process.
     */
    fun lastFix(ctx: Context, visitId: Long): Location? {
        val p = prefs(ctx)
        if (!p.contains(K_LAST_VISIT) || p.getLong(K_LAST_VISIT, 0L) != visitId) return null
        val lat = p.getString(K_LAST_LAT, null)?.toDoubleOrNull() ?: return null
        val lng = p.getString(K_LAST_LNG, null)?.toDoubleOrNull() ?: return null
        return Location("journal").apply {
            latitude = lat
            longitude = lng
            time = p.getLong(K_LAST_T, 0L)
        }
    }

    /**
     * Appends one fix, assigning it the next sequence number. The counter is
     * committed before the line is written: a crash in between leaves a gap,
     * never a reused number.
     */
    fun append(ctx: Context, fix: JSONObject): Long = synchronized(lock) {
        val p = prefs(ctx)
        val seq = p.getLong(K_SEQ, 0L) + 1
        p.edit()
            .putLong(K_SEQ, seq)
            .putLong(K_LAST_VISIT, fix.getLong("v"))
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
            "v" to o.getLong("v"),
        )
    }
}
