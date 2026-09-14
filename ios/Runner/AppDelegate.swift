import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // Work-day route capture (WorkdayLocation.swift). Resumed here, before
    // Flutter is up, so a background relaunch for a location event keeps an
    // open work day recording.
    if let registrar = self.registrar(forPlugin: "WorkdayLocation") {
      WorkdayLocation.shared.register(messenger: registrar.messenger())
    }
    WorkdayLocation.shared.resumeIfActive()
    // Route APNs callbacks through UNUserNotificationCenter so firebase_messaging
    // can map the APNs token to an FCM token and display foreground banners.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
