import CoreLocation
import Flutter
import UIKit

/// Records the GPS trail of the one customer visit that is in progress, on
/// iOS — the counterpart of `VisitLocationService.kt`, `VisitLocationStore.kt`
/// and `VisitLocationChannel.kt`, speaking the same method channel and writing
/// the same journal format, so `VisitTrailTracker` (Dart) drives both
/// platforms alike.
///
/// **When.** Started by Dart only after the server confirmed Start Visit (the
/// visit is `in_progress`) and stopped the moment the visit is ended, or on
/// sign-out. The config is deactivated before updates are stopped, and every
/// delivered location re-reads it, so nothing is recorded after End.
///
/// **Background.** Standard location updates with the `location` background
/// mode, `allowsBackgroundLocationUpdates` and no automatic pausing keep the
/// trail growing with the app in the background or the screen locked, under
/// "While Using" authorization, because capture is always started from the
/// foreground (the Start tap, or the app being opened during a visit). iOS
/// shows its blue location indicator for as long as it runs. On iOS 17+ a
/// `CLBackgroundActivitySession` is held too, which Apple requires for
/// While-Using apps to keep receiving updates in the background.
///
/// **Restart.** iOS does not relaunch an app for standard updates. Only if the
/// user chose "Always" in Settings does significant-change monitoring run
/// alongside, so a significant move relaunches an app the system terminated
/// during a visit, and `resumeIfActive(relaunchedForLocation:)` carries on
/// from the stored config.
/// iOS never relaunches an app the user force-quit; Dart restarts capture when
/// the app is opened again while the visit is still in progress.
///
/// Each accepted fix is appended to a journal file and synced to disk before
/// anything depends on the network or on the Flutter engine; Dart reads it,
/// buffers the fixes for upload and acknowledges them by sequence number.
final class VisitLocation: NSObject, CLLocationManagerDelegate {
  static let shared = VisitLocation()

  private static let channelName = "net.digitalharbor.visits/visit_location"

  /// Keeps a fix this far from the last one even inside the sampling interval.
  private static let burstDistance: CLLocationDistance = 15
  /// Cap on the accuracy-based allowance for a stationary device's wander.
  private static let maxJitter: CLLocationDistance = 15
  /// After `starvedMs` without a kept fix, accept accuracy up to this.
  private static let relaxedMaxAccuracy: CLLocationAccuracy = 100
  private static let starvedMs: Int64 = 30_000
  private static let journalFolder = "visit_tracking"
  private static let journalName = "visit_fixes.jsonl"

  private enum Key {
    static let active = "visit_capture.active"
    static let visitId = "visit_capture.visit_id"
    static let startedAt = "visit_capture.started_at_ms"
    static let minDistance = "visit_capture.min_distance_m"
    static let minInterval = "visit_capture.min_interval_ms"
    static let maxAccuracy = "visit_capture.max_accuracy_m"
    static let seq = "visit_capture.seq"
    static let lastVisit = "visit_capture.last_fix_visit"
    static let lastTime = "visit_capture.last_fix_t"
    static let lastLatitude = "visit_capture.last_fix_lat"
    static let lastLongitude = "visit_capture.last_fix_lng"
  }

  /// UserDefaults prefix and journal folder of the cancelled work-day capture.
  private static let legacyKeyPrefix = "workday_capture."
  private static let legacyFolder = "workday"

  private struct Config {
    let visitId: Int64
    /// Fixes stamped before this are cached positions replayed by the OS.
    let startedAtMs: Int64
    let minDistance: Double
    let minIntervalMs: Int64
    let maxAccuracy: Double
  }

  private struct CaptureError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
  }

  private static let backgroundModeDeclared: Bool =
    (Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String])?.contains("location") == true

  private let defaults = UserDefaults.standard
  private let journalLock = NSLock()
  private var manager: CLLocationManager!
  private var lastKept: (visitId: Int64, time: Int64, location: CLLocation)?
  private var updating = false
  /// `CLBackgroundActivitySession` on iOS 17+, typed loosely for iOS 15/16.
  private var backgroundActivity: AnyObject?

  private override init() {
    super.init()
    // Created on the main thread (first use is in AppDelegate), so delegate
    // callbacks arrive there too.
    manager = CLLocationManager()
    manager.delegate = self
  }

  // MARK: - Flutter channel

  func register(messenger: FlutterBinaryMessenger) {
    purgeLegacy()
    let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return result(FlutterMethodNotImplemented) }
      let args = call.arguments as? [String: Any] ?? [:]
      do {
        switch call.method {
        case "start":
          try self.start(args)
          result(true)
        case "stop":
          self.stop()
          result(true)
        case "status":
          var status: [String: Any] = ["active": false, "running": self.updating]
          if let config = self.loadConfig() {
            status["active"] = true
            status["visitId"] = NSNumber(value: config.visitId)
          }
          result(status)
        case "read":
          result(try self.read(max: Int(Self.int64(args["max"]) ?? 500)))
        case "ack":
          guard let seq = Self.int64(args["throughSeq"]) else { throw CaptureError("throughSeq is required") }
          try self.ack(through: seq)
          result(true)
        default:
          result(FlutterMethodNotImplemented)
        }
      } catch {
        result(FlutterError(code: "visit_location", message: "\(error)", details: nil))
      }
    }
  }

  /// Called at launch. With no active visit it makes sure nothing is running.
  /// Capture is resumed here only when iOS relaunched the app in the
  /// background for a location event (a significant move during a visit,
  /// "Always" only), where Flutter may never get to run its checks. On a
  /// normal launch Dart asks the server first and restarts capture only for a
  /// visit that is still in progress — never for one ended elsewhere meanwhile.
  func resumeIfActive(relaunchedForLocation: Bool) {
    guard loadConfig() != nil else {
      endUpdates()
      return
    }
    if relaunchedForLocation && isAuthorized(manager.authorizationStatus) {
      beginUpdates()
    }
  }

  // MARK: - Capture control

  private func start(_ args: [String: Any]) throws {
    guard let visitId = Self.int64(args["visitId"]) else {
      throw CaptureError("visitId is required")
    }
    let startedAt = Self.int64(args["sinceMs"]) ?? Self.nowMs()
    if (defaults.object(forKey: Key.lastVisit) as? NSNumber)?.int64Value != visitId {
      // The visit's start position counts as its first recorded fix, so the
      // first update at that spot is not recorded twice.
      if let lat = Self.double(args["seedLatitude"]), let lng = Self.double(args["seedLongitude"]) {
        defaults.set(NSNumber(value: visitId), forKey: Key.lastVisit)
        defaults.set(NSNumber(value: startedAt), forKey: Key.lastTime)
        defaults.set(lat, forKey: Key.lastLatitude)
        defaults.set(lng, forKey: Key.lastLongitude)
      } else {
        [Key.lastVisit, Key.lastTime, Key.lastLatitude, Key.lastLongitude].forEach(defaults.removeObject(forKey:))
      }
    }
    if lastKept?.visitId != visitId { lastKept = nil }
    defaults.set(NSNumber(value: visitId), forKey: Key.visitId)
    defaults.set(NSNumber(value: startedAt), forKey: Key.startedAt)
    defaults.set(Self.double(args["minDistanceMeters"]) ?? 10, forKey: Key.minDistance)
    defaults.set(NSNumber(value: Self.int64(args["minIntervalMs"]) ?? 4_000), forKey: Key.minInterval)
    defaults.set(Self.double(args["maxAccuracyMeters"]) ?? 50, forKey: Key.maxAccuracy)
    defaults.set(true, forKey: Key.active)

    guard isAuthorized(manager.authorizationStatus) else {
      endUpdates()
      // Reported to Dart, which shows the trail as paused until access is back.
      throw CaptureError("location permission missing")
    }
    beginUpdates()
  }

  /// Ends capture. Deactivated first, so a fix delivered before the manager
  /// has stopped is ignored.
  private func stop() {
    defaults.set(false, forKey: Key.active)
    defaults.removeObject(forKey: Key.visitId)
    endUpdates()
  }

  private func beginUpdates() {
    guard let config = loadConfig() else { return }
    manager.desiredAccuracy = kCLLocationAccuracyBest
    manager.distanceFilter = config.minDistance
    // Generic activity: employees walk and drive, and the trail is recorded
    // as measured.
    manager.activityType = .other
    manager.pausesLocationUpdatesAutomatically = false
    if Self.backgroundModeDeclared {
      // Setting this without the `location` background mode raises an
      // exception, hence the check.
      manager.allowsBackgroundLocationUpdates = true
      manager.showsBackgroundLocationIndicator = true
    }
    if #available(iOS 17.0, *), backgroundActivity == nil {
      backgroundActivity = CLBackgroundActivitySession()
    }
    manager.startUpdatingLocation()
    if manager.authorizationStatus == .authorizedAlways {
      manager.startMonitoringSignificantLocationChanges()
    }
    updating = true
  }

  private func endUpdates() {
    manager.stopUpdatingLocation()
    manager.stopMonitoringSignificantLocationChanges()
    if Self.backgroundModeDeclared {
      manager.allowsBackgroundLocationUpdates = false
    }
    if #available(iOS 17.0, *) {
      (backgroundActivity as? CLBackgroundActivitySession)?.invalidate()
    }
    backgroundActivity = nil
    updating = false
  }

  private func isAuthorized(_ status: CLAuthorizationStatus) -> Bool {
    status == .authorizedAlways || status == .authorizedWhenInUse
  }

  private func loadConfig() -> Config? {
    guard defaults.bool(forKey: Key.active),
      let visitId = (defaults.object(forKey: Key.visitId) as? NSNumber)?.int64Value
    else { return nil }
    return Config(
      visitId: visitId,
      startedAtMs: (defaults.object(forKey: Key.startedAt) as? NSNumber)?.int64Value ?? 0,
      minDistance: defaults.object(forKey: Key.minDistance) as? Double ?? 10,
      minIntervalMs: (defaults.object(forKey: Key.minInterval) as? NSNumber)?.int64Value ?? 4_000,
      maxAccuracy: defaults.object(forKey: Key.maxAccuracy) as? Double ?? 50
    )
  }

  /// Removes what the cancelled work-day capture left behind: its defaults
  /// (so nothing can read them as an active capture) and its journal.
  private func purgeLegacy() {
    for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(Self.legacyKeyPrefix) {
      defaults.removeObject(forKey: key)
    }
    if let support = try? FileManager.default.url(
      for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    {
      try? FileManager.default.removeItem(at: support.appendingPathComponent(Self.legacyFolder, isDirectory: true))
    }
  }

  // MARK: - CLLocationManagerDelegate

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    guard loadConfig() != nil else { return }
    if isAuthorized(manager.authorizationStatus) {
      beginUpdates()  // also adds significant-change monitoring after an upgrade to Always
    } else {
      // The visit stays in progress; Dart shows the trail as paused and
      // restarts capture once access is granted again.
      endUpdates()
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    if (error as? CLError)?.code == .denied {
      endUpdates()
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    for location in locations {
      record(location)
    }
  }

  /// The acceptance rules of `VisitLocationService.onLocationChanged`.
  private func record(_ location: CLLocation) {
    // Re-read every time: a deactivated config means the visit ended.
    guard let config = loadConfig() else {
      if updating { endUpdates() }
      return
    }
    let time = Int64((location.timestamp.timeIntervalSince1970 * 1000).rounded())
    guard time >= config.startedAtMs, location.horizontalAccuracy >= 0 else { return }
    // After a relaunch the in-memory history is gone: continue from the last
    // fix the journal recorded, so the spot the device sits at isn't recorded again.
    if lastKept?.visitId != config.visitId {
      lastKept = restoredLastFix(visitId: config.visitId)
    }
    let last = lastKept
    let accuracy = location.horizontalAccuracy
    if accuracy > config.maxAccuracy {
      let starved = last.map { time - $0.time >= Self.starvedMs } ?? false
      if !starved || accuracy > Self.relaxedMaxAccuracy { return }
    }
    if let last = last {
      if time <= last.time { return }
      let moved = location.distance(from: last.location)
      let jitter = min(accuracy / 2, Self.maxJitter)
      if moved < max(config.minDistance, jitter) { return }
      if time - last.time < config.minIntervalMs && moved < Self.burstDistance { return }
    }
    lastKept = (config.visitId, time, location)

    var fix: [String: Any] = [
      "t": NSNumber(value: time),
      "lat": location.coordinate.latitude,
      "lng": location.coordinate.longitude,
      "v": NSNumber(value: config.visitId),
      "acc": accuracy,
    ]
    if location.verticalAccuracy > 0 { fix["alt"] = location.altitude }
    if location.speed >= 0 { fix["spd"] = location.speed }
    if location.course >= 0 { fix["hdg"] = location.course }
    do {
      let seq = try append(fix)
      NSLog("[VisitLocation] fix #%lld recorded", seq)
    } catch {
      NSLog("[VisitLocation] journal write failed: %@", "\(error)")
    }
  }

  private func restoredLastFix(visitId: Int64) -> (visitId: Int64, time: Int64, location: CLLocation)? {
    guard (defaults.object(forKey: Key.lastVisit) as? NSNumber)?.int64Value == visitId,
      let lat = defaults.object(forKey: Key.lastLatitude) as? Double,
      let lng = defaults.object(forKey: Key.lastLongitude) as? Double
    else { return nil }
    let time = (defaults.object(forKey: Key.lastTime) as? NSNumber)?.int64Value ?? 0
    return (visitId, time, CLLocation(latitude: lat, longitude: lng))
  }

  // MARK: - Journal

  private func journalURL() throws -> URL {
    let support = try FileManager.default.url(
      for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    var folder = support.appendingPathComponent(Self.journalFolder, isDirectory: true)
    if !FileManager.default.fileExists(atPath: folder.path) {
      // Readable and writable while the device is locked (after the first
      // unlock since boot): the trail keeps growing with the screen locked.
      try FileManager.default.createDirectory(
        at: folder, withIntermediateDirectories: true,
        attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try? folder.setResourceValues(values)
    }
    return folder.appendingPathComponent(Self.journalName)
  }

  /// Appends one fix with the next sequence number, synced to disk.
  private func append(_ fix: [String: Any]) throws -> Int64 {
    journalLock.lock()
    defer { journalLock.unlock() }
    let seq = ((defaults.object(forKey: Key.seq) as? NSNumber)?.int64Value ?? 0) + 1
    // The counter is stored before the line is written (as on Android): a
    // crash in between leaves a gap, never a reused number.
    defaults.set(NSNumber(value: seq), forKey: Key.seq)
    var line = fix
    line["seq"] = NSNumber(value: seq)
    var data = try JSONSerialization.data(withJSONObject: line)
    data.append(0x0A)
    let url = try journalURL()
    if !FileManager.default.fileExists(atPath: url.path) {
      FileManager.default.createFile(
        atPath: url.path, contents: nil,
        attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
    }
    let handle = try FileHandle(forWritingTo: url)
    defer { try? handle.close() }
    try handle.seekToEnd()
    try handle.write(contentsOf: data)
    try handle.synchronize()
    defaults.set(fix["v"], forKey: Key.lastVisit)
    defaults.set(fix["t"], forKey: Key.lastTime)
    defaults.set(fix["lat"], forKey: Key.lastLatitude)
    defaults.set(fix["lng"], forKey: Key.lastLongitude)
    return seq
  }

  /// Up to `max` journalled fixes, oldest first. A line torn by a crash is skipped.
  private func read(max: Int) throws -> [[String: Any]] {
    journalLock.lock()
    defer { journalLock.unlock() }
    guard let data = try? Data(contentsOf: try journalURL()), !data.isEmpty else { return [] }
    var out: [[String: Any]] = []
    for line in data.split(separator: 0x0A) {
      if out.count >= max { break }
      guard let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
        object["t"] != nil, object["seq"] != nil, object["v"] != nil
      else { continue }
      out.append(object)
    }
    return out
  }

  /// Removes every fix with a sequence number up to and including `seq`.
  private func ack(through seq: Int64) throws {
    journalLock.lock()
    defer { journalLock.unlock() }
    let url = try journalURL()
    guard let data = try? Data(contentsOf: url) else { return }
    var keep = Data()
    for line in data.split(separator: 0x0A) {
      guard let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any] else { continue }
      if ((object["seq"] as? NSNumber)?.int64Value ?? 0) > seq {
        keep.append(contentsOf: line)
        keep.append(0x0A)
      }
    }
    if keep.isEmpty {
      try? FileManager.default.removeItem(at: url)
    } else {
      try keep.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
  }

  // MARK: - Helpers

  private static func int64(_ value: Any?) -> Int64? { (value as? NSNumber)?.int64Value }
  private static func double(_ value: Any?) -> Double? { (value as? NSNumber)?.doubleValue }
  private static func nowMs() -> Int64 { Int64((Date().timeIntervalSince1970 * 1000).rounded()) }
}
