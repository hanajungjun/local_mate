import UIKit
import Flutter
import GoogleMaps // 👈 구글맵 모듈

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // 형님이 발급받은 키를 여기에 넣었습니다
    GMSServices.provideAPIKey("AIzaSyADa0S7smWmebzAZ2f-wP59G35B8D3Fz2I")
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}