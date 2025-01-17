//
//  ecochicv4App.swift
//  ecochicv4
//
//  Created by Manuel Teran on 2024-12-27.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()

        return true
    }
}

@main
struct EcoChic: App {
    // Register AppDelegate for Firebase and Google Maps setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @State private var appController = AppController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appController)
                .onAppear { appController.listenToAuthChanges() }
        }
    }
}
