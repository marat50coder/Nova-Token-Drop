import Flutter
import UIKit
import UserNotifications

/// Captures a cold-start notification tap (app launched from a killed state by
/// tapping a push) and stashes the deep-link URL into UserDefaults so the Dart
/// side (`ColdTapReader`) can consume it and route straight to the WebView.
class SceneDelegate: FlutterSceneDelegate {
  // Must match `ColdTapReader.coldTapKey` on the Dart side, with the
  // SharedPreferences `flutter.` prefix added here.
  static let coldRouteKey = "flutter.ntd_route_seed"

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    guard
      let response = connectionOptions.notificationResponse,
      let destination = Self.destination(
        inside: response.notification.request.content.userInfo
      )
    else { return }

    let defaults = UserDefaults.standard
    defaults.set(destination, forKey: Self.coldRouteKey)
    defaults.synchronize()

    #if DEBUG
    NSLog("[NTD.ROUTE] captured notification destination")
    #endif
  }

  private static func destination(
    inside payload: [AnyHashable: Any]
  ) -> String? {
    let candidates = ["deep_link", "target", "url", "deeplink", "link"]

    func firstValue(in dictionary: [AnyHashable: Any]) -> String? {
      for candidate in candidates {
        guard let value = dictionary[candidate] as? String else { continue }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
      }
      return nil
    }

    if let direct = firstValue(in: payload) { return direct }

    for container in ["payload", "data"] {
      if let nested = payload[container] as? [AnyHashable: Any],
         let value = firstValue(in: nested) {
        return value
      }
    }
    return nil
  }
}
