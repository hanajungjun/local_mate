import UIKit
import Flutter
import GoogleMaps // 💡 1. 지도를 위해 이 라인이 꼭 필요합니다!

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 💡 2. 여기에 형님의 API 키를 수줍게 넣어줍니다.
    GMSServices.provideAPIKey("AIzaSyADa0S7smWmebzAZ2f-wP59G35B8D3Fz2I")

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}