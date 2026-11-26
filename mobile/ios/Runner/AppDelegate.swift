import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let badgeChannel = FlutterMethodChannel(
      name: "com.morethanhuman.curitalk/badge",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    badgeChannel.setMethodCallHandler { call, result in
      guard #available(iOS 16.0, *) else {
        result(call.method == "status" || call.method == "request" ? "unsupported" : nil)
        return
      }
      let center = UNUserNotificationCenter.current()
      let status = {
        center.getNotificationSettings { settings in
          let value = settings.authorizationStatus == .notDetermined ? "notDetermined"
            : (settings.badgeSetting == .enabled ? "allowed" : "denied")
          DispatchQueue.main.async { result(value) }
        }
      }
      switch call.method {
      case "status": status()
      case "request":
        center.getNotificationSettings { settings in
          guard settings.authorizationStatus == .notDetermined else { status(); return }
          center.requestAuthorization(options: [.badge]) { _, error in
            if let error = error {
              DispatchQueue.main.async { result(FlutterError(code: "BADGE_PERMISSION", message: error.localizedDescription, details: nil)) }
            } else { status() }
          }
        }
      case "set":
        guard let count = call.arguments as? Int, count == 0 || count == 1 else {
          result(FlutterError(code: "BADGE_COUNT", message: "Expected 0 or 1", details: nil)); return
        }
        center.setBadgeCount(count) { error in
          DispatchQueue.main.async {
            if let error = error {
              result(FlutterError(code: "BADGE_WRITE", message: error.localizedDescription, details: nil))
            } else { result(nil) }
          }
        }
      case "settings":
        guard let url = URL(string: UIApplication.openSettingsURLString) else { result(nil); return }
        UIApplication.shared.open(url) { _ in result(nil) }
      default: result(FlutterMethodNotImplemented)
      }
    }
    let channel = FlutterMethodChannel(
      name: "com.morethanhuman.curitalk/snack_widget",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "read":
        result(SnackWidgetStore.readRaw())
      case "write":
        guard let raw = call.arguments as? String, SnackWidgetStore.saveRaw(raw) else {
          result(FlutterError(code: "INVALID_SNAPSHOT", message: "Invalid snack widget snapshot", details: nil))
          return
        }
        result(nil)
      case "clear":
        SnackWidgetStore.clear()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
