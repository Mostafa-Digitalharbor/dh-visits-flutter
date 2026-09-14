import CoreLocation
import Flutter
import UIKit

/// Captures the employee's position for the whole of an active work day on
/// iOS — the counterpart of `WorkdayLocationService.kt`, `WorkdayStore.kt` and
/// `WorkdayChannel.kt`, speaking the same method channel and writing the same
/// journal format, so `WorkdayTracker` (Dart) drives both platforms alike.
///
/// **Background.** Standard location updates with the `location` background
/// mode, `allowsBackgroundLocationUpdates` and no automatic pausing keep
/// capture running with the app in the background or the screen locked, for
/// "While Using" as well as "Always" authorization, as long as capture was
/// started from the foreground (the Start tap, or the app being opened). iOS
/// shows its blue location indicator for as long as it runs. On iOS 17+ a
/// `CLBackgroundActivitySession` is held too, which is what Apple requires for
/// While-Using apps to keep receiving updates in the background.
///
/// **Restart.** iOS does not relaunch an app for standard updates. With
/// "Always" authorization significant-change monitoring runs alongside, so
/// after the system terminated the app a significant move relaunches it in the
/// background, and `resumeIfActive()` restarts capture from the stored config.
/// iOS does not relaunch an app the user force-quit.
///
/// **Raw GPS.** Fixes are recorded as Core Location reports them, with the
/// same acceptance rules as Android; nothing is snapped or smoothed here.
///
/// Each accepted fix is appended to a journal file and synced to disk before
/// anything depends on the network or on the Flutter engine; Dart reads it,
/// queues the fixes for upload and acknowledges them by sequence number.
final class WorkdayLocation: NSObject, CLLocationManagerDelegate {
  static let shared = WorkdayLocation()

  private static let channelName = "net.digitalharbor.visits/workday_location"

  /// Keeps a fix this far from the last one even inside the sampling interval.
  private static let burstDistance: CLLocationDistance = 15
  /// Cap on the accuracy-based allowance for a stationary device's wander.
  private static let maxJitter: CLLocationDistance = 15
  /// After `starvedMs` without a kept fix, accept accuracy up to this.
  private static let relaxedMaxAccuracy: CLLocationAccuracy = 100
  private static let starvedMs: Int64 = 30_000
  /// `NSLocationTemporaryUsageDescriptionDictionary` key in Info.plist.
  private static let fullAccuracyPurposeKey = "WorkdayRoute"

  private enum Key {
    static let active = "workday_capture.active"
    static let session = "workday_capture.session_uid"
    static let minDistance = "workday_capture.min_distance_m"
    static let minInterval = "workday_capture.min_interval_ms"
    static let maxAccuracy = "workday_capture.max_accuracy_m"
    static let startedAt = "workday_capture.started_at_ms"
    static let visitId = "workday_capture.visit_id"
    static let visitSince = "workday_capture.visit_since_ms"
    static let seq = "workday_capture.seq"
    static let lastSession = "workday_capture.last_fix_session"
    static let lastTime = "workday_capture.last_fix_t"
    static let lastLatitude = "workday_capture.last_fix_lat"
    static let lastLongitude = "workday_capture.last_fix_lng"
  }

  private struct Config {
    let sessionUid: String
    let minDistance: Double
    let minIntervalMs: Int64
    let maxAccuracy: Double
    /// Fixes stamped before this are cached positions replayed by the OS.
    let startedAtMs: Int64
  }

  private struct WorkdayError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
  }

  private static let backgroundModeDeclared: Bool =
    (Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String])?.contains("location") == true

  private let defaults = UserDefaults.standard
  private let journalLock = NSLock()
  private var manager: CLLocationManager!
  private var lastKept: (time: Int64, location: CLLocation)?
  private var updating = false
  /// `CLBackgroundActivitySession` on iOS 17+, typed loosely for iOS 15/16.
  private var backgroundActivity: AnyObject?
  private var authorizationWaiters: [() -> Void] = []

  private override init() {
    super.init()
    // Created on the main thread (first use is in AppDelegate), so delegate
    // callbacks arrive there too.
    manager = CLLocationManager()
    manager.delegate = self
  }

  // MARK: - Flutter channel

  func register(messenger: FlutterBinaryMessenger) {
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
        case "setVisit":
          self.setVisit(Self.int64(args["visitId"]), sinceMs: Self.int64(args["sinceMs"]) ?? Self.nowMs())
          result(true)
        case "status":
          result(["active": self.defaults.bool(forKey: Key.active), "running": self.updating])
        case "read":
          result(try self.read(max: Int(Self.int64(args["max"]) ?? 500)))
        case "ack":
          guard let seq = Self.int64(args["throughSeq"]) else { throw WorkdayError("throughSeq is required") }
          try self.ack(through: seq)
          result(true)
        case "authorization":
          result(self.authorizationInfo())
        case "requestAlways":
          self.requestAlways { result(self.authorizationInfo()) }
        case "requestFullAccuracy":
          self.requestFullAccuracy { result(self.authorizationInfo()) }
        default:
          result(FlutterMethodNotImplemented)
        }
      } catch {
        result(FlutterError(code: "workday_location", message: "\(error)", details: nil))
      }
    }
  }

  /// Called at launch — including a background relaunch for a location event —
  /// so an open work day keeps being captured without waiting for Flutter.
  func resumeIfActive() {
    guard loadConfig() != nil else {
      endUpdates()
      return
    }
    if isAuthorized(manager.authorizationStatus) {
      beginUpdates()
    }
  }

  // MARK: - Capture control

  private func start(_ args: [String: Any]) throws {
    guard let session = args["sessionUid"] as? String, !session.isEmpty else {
      throw WorkdayError("sessionUid is required")
    }
    let startedAt = Self.int64(args["startedAtMs"]) ?? Self.nowMs()
    if defaults.string(forKey: Key.lastSession) != session {
      // The day's start position counts as its first recorded fix, so the
      // first update at that spot is not recorded twice.
      if let lat = Self.double(args["seedLatitude"]), let lng = Self.double(args["seedLongitude"]) {
        defaults.set(session, forKey: Key.lastSession)
        defaults.set(NSNumber(value: startedAt), forKey: Key.lastTime)
        defaults.set(lat, forKey: Key.lastLatitude)
        defaults.set(lng, forKey: Key.lastLongitude)
      } else {
        [Key.lastSession, Key.lastTime, Key.lastLatitude, Key.lastLongitude].forEach(defaults.removeObject(forKey:))
      }
      lastKept = nil
    }
    defaults.set(true, forKey: Key.active)
    defaults.set(session, forKey: Key.session)
    defaults.set(Self.double(args["minDistanceMeters"]) ?? 5, forKey: Key.minDistance)
    defaults.set(NSNumber(value: Self.int64(args["minIntervalMs"]) ?? 4_000), forKey: Key.minInterval)
    defaults.set(Self.double(args["maxAccuracyMeters"]) ?? 50, forKey: Key.maxAccuracy)
    defaults.set(NSNumber(value: startedAt), forKey: Key.startedAt)
    setVisit(Self.int64(args["visitId"]), sinceMs: Self.int64(args["visitSinceMs"]) ?? Self.nowMs())

    guard isAuthorized(manager.authorizationStatus) else {
      endUpdates()
      // Reported to Dart, which shows capture as paused until access is back.
      throw WorkdayError("location permission missing")
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

  private func setVisit(_ visitId: Int64?, sinceMs: Int64) {
    defaults.set(NSNumber(value: sinceMs), forKey: Key.visitSince)
    if let visitId = visitId {
      defaults.set(NSNumber(value: visitId), forKey: Key.visitId)
    } else {
      defaults.removeObject(forKey: Key.visitId)
    }
  }

  private func beginUpdates() {
    guard let config = loadConfig() else { return }
    manager.desiredAccuracy = kCLLocationAccuracyBest
    manager.distanceFilter = config.minDistance
    // Generic activity: employees walk and drive, and the route is recorded
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
    guard defaults.bool(forKey: Key.active), let session = defaults.string(forKey: Key.session) else { return nil }
    return Config(
      sessionUid: session,
      minDistance: defaults.object(forKey: Key.minDistance) as? Double ?? 5,
      minIntervalMs: (defaults.object(forKey: Key.minInterval) as? NSNumber)?.int64Value ?? 4_000,
      maxAccuracy: defaults.object(forKey: Key.maxAccuracy) as? Double ?? 50,
      startedAtMs: (defaults.object(forKey: Key.startedAt) as? NSNumber)?.int64Value ?? 0
    )
  }

  // MARK: - Permissions

  private func authorizationInfo() -> [String: Any] {
    let status: String
    switch manager.authorizationStatus {
    case .notDetermined: status = "notDetermined"
    case .restricted: status = "restricted"
    case .denied: status = "denied"
    case .authorizedAlways: status = "always"
    case .authorizedWhenInUse: status = "whenInUse"
    @unknown default: status = "denied"
    }
    return [
      "status": status,
      "precise": manager.accuracyAuthorization == .fullAccuracy,
      "backgroundMode": Self.backgroundModeDeclared,
    ]
  }

  /// Asks to upgrade "While Using" to "Always" — iOS shows that prompt once.
  /// Completes when the user answered, or at once when iOS showed nothing.
  private func requestAlways(_ done: @escaping () -> Void) {
    guard manager.authorizationStatus == .authorizedWhenInUse else { return done() }
    var finished = false
    var resigned = false
    var observers: [NSObjectProtocol] = []
    let finish = {
      guard !finished else { return }
      finished = true
      observers.forEach(NotificationCenter.default.removeObserver)
      done()
    }
    observers.append(NotificationCenter.default.addObserver(
      forName: UIApplication.willResignActiveNotification, object: nil, queue: .main
    ) { _ in resigned = true })
    observers.append(NotificationCenter.default.addObserver(
      forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
    ) { _ in if resigned { finish() } })
    authorizationWaiters.append(finish)
    manager.requestAlwaysAuthorization()
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      if !resigned { finish() }  // no prompt appeared: already answered before
    }
  }

  /// "Precise Location" off: asks for full accuracy for this app session.
  private func requestFullAccuracy(_ done: @escaping () -> Void) {
    guard manager.accuracyAuthorization == .reducedAccuracy else { return done() }
    manager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: Self.fullAccuracyPurposeKey) { _ in
      DispatchQueue.main.async { done() }
    }
  }

  // MARK: - CLLocationManagerDelegate

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    let waiters = authorizationWaiters
    authorizationWaiters.removeAll()
    waiters.forEach { $0() }
    guard loadConfig() != nil else { return }
    if isAuthorized(manager.authorizationStatus) {
      beginUpdates()  // also adds significant-change monitoring after an upgrade to Always
    } else {
      // The work day stays open; Dart shows capture as paused and restarts
      // it once access is granted again.
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

  /// The acceptance rules of `WorkdayLocationService.onLocationChanged`.
  private func record(_ location: CLLocation) {
    // Re-read every time: a deactivated config means the day ended.
    guard let config = loadConfig() else { return }
    let time = Int64((location.timestamp.timeIntervalSince1970 * 1000).rounded())
    guard time >= config.startedAtMs, location.horizontalAccuracy >= 0 else { return }
    // After a relaunch the in-memory history is gone: continue from the last
    // fix the journal recorded, so the spot the device sits at isn't recorded again.
    if lastKept == nil {
      lastKept = restoredLastFix(session: config.sessionUid)
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
    lastKept = (time, location)

    var fix: [String: Any] = [
      "t": NSNumber(value: time),
      "lat": location.coordinate.latitude,
      "lng": location.coordinate.longitude,
      "s": config.sessionUid,
      "acc": accuracy,
    ]
    if location.verticalAccuracy > 0 { fix["alt"] = location.altitude }
    if location.speed >= 0 { fix["spd"] = location.speed }
    if location.course >= 0 { fix["hdg"] = location.course }
    if let visit = (defaults.object(forKey: Key.visitId) as? NSNumber)?.int64Value,
      time >= ((defaults.object(forKey: Key.visitSince) as? NSNumber)?.int64Value ?? 0) {
      fix["v"] = NSNumber(value: visit)
    }
    do {
      let seq = try append(fix)
      NSLog("[WorkdayLocation] fix #%lld recorded", seq)
    } catch {
      NSLog("[WorkdayLocation] journal write failed: %@", "\(error)")
    }
  }

  private func restoredLastFix(session: String) -> (time: Int64, location: CLLocation)? {
    guard defaults.string(forKey: Key.lastSession) == session,
      let lat = defaults.object(forKey: Key.lastLatitude) as? Double,
      let lng = defaults.object(forKey: Key.lastLongitude) as? Double
    else { return nil }
    let time = (defaults.object(forKey: Key.lastTime) as? NSNumber)?.int64Value ?? 0
    return (time, CLLocation(latitude: lat, longitude: lng))
  }

  // MARK: - Journal

  private func journalURL() throws -> URL {
    let support = try FileManager.default.url(
      for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    var folder = support.appendingPathComponent("workday", isDirectory: true)
    if !FileManager.default.fileExists(atPath: folder.path) {
      // Readable and writable while the device is locked (after the first
      // unlock since boot): capture continues with the screen locked.
      try FileManager.default.createDirectory(
        at: folder, withIntermediateDirectories: true,
        attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try? folder.setResourceValues(values)
    }
    return folder.appendingPathComponent("workday_fixes.jsonl")
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
    defaults.set(fix["s"], forKey: Key.lastSession)
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
        object["t"] != nil, object["seq"] != nil
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
