import SwiftUI
import FirebaseCore
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        if Auth.auth().isSignIn(withEmailLink: url.absoluteString) {
            // Notify SignInView that the email link was clicked
            NotificationCenter.default.post(name: NSNotification.Name("EmailLinkReceived"), object: url)
            return true
        }
        return false
    }
}

@main
struct EcoChic: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var appController = AppController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appController)
                .onAppear { appController.listenToAuthChanges() }
                .onOpenURL { url in
                    if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                       let ref = components.queryItems?.first(where: { $0.name == "ref" })?.value {
                        UserDefaults.standard.set(ref, forKey: "referrerCode")
                        print("Referral code captured: \(ref)")
                    }
                }
        }
    }
}
