import Flutter
import UIKit

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
