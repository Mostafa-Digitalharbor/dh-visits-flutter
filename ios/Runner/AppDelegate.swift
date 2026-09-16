import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // Visit trail capture (VisitLocation.swift). Registered before Flutter is
    // up; a background relaunch for a location event keeps an active visit
    // recording, and nothing runs when no visit is active.
    if let registrar = self.registrar(forPlugin: "VisitLocation") {
      VisitLocation.shared.register(messenger: registrar.messenger())
    }
    VisitLocation.shared.resumeIfActive(
      relaunchedForLocation: launchOptions?[.location] != nil)
    // Route APNs callbacks through UNUserNotificationCenter so firebase_messaging
    // can map the APNs token to an FCM token and display foreground banners.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
