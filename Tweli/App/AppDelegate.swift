//
//  AppDelegate.swift
//  Tweli
//
//  Bridges UIApplicationDelegate-only callbacks into the SwiftUI app:
//  Firebase bootstrap, APNs/FCM token plumbing, and remote-notification
//  nudges. Wired into SwiftUI via @UIApplicationDelegateAdaptor in TweliApp.
//
//  Background cross-device push needs a Cloud Function (Blaze plan) — the
//  didReceiveRemoteNotification path below is pre-staged for that and is a
//  redundant nudge today; snapshot listeners are the primary sync channel.
//

import UIKit
import FirebaseCore
import FirebaseMessaging

final class AppDelegate: NSObject, UIApplicationDelegate {

    /// Set by TweliApp so the delegate can hand events to the AppViewModel.
    var onRemoteChange: (() -> Void)?
    var onFCMToken: ((String) -> Void)?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Must run before any Firebase API is touched (Auth, Firestore, Messaging).
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        application.registerForRemoteNotifications()
        return true
    }

    /// APNs token arrives → hand it to FCM so it can mint the FCM token.
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[Push] APNs registration failed: \(error.localizedDescription)")
    }

    /// Remote notification (future Blaze-backed push): nudge a sync.
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        onRemoteChange?()
        return .newData
    }
}

extension AppDelegate: MessagingDelegate {
    /// FCM token minted/rotated → store it on the space doc (fcmTokens[uid])
    /// so a future Cloud Function can address this device.
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        onFCMToken?(fcmToken)
    }
}
