//
//  AppDelegate.swift
//  Tweli
//
//  Bridges CloudKit callbacks that only the UIApplicationDelegate receives:
//  accepting an invite share, and silent pushes when the shared zone changes.
//  Wired into SwiftUI via @UIApplicationDelegateAdaptor in TweliApp.
//

import UIKit
import CloudKit

final class AppDelegate: NSObject, UIApplicationDelegate {

    /// Set by TweliApp so the delegate can hand events to the AppViewModel.
    var onAcceptShare: ((CKShare.Metadata) -> Void)?
    var onRemoteChange: (() -> Void)?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    /// Partner tapped the invite link and confirmed — the OS hands us the share.
    func application(_ application: UIApplication,
                     userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
        onAcceptShare?(metadata)
    }

    /// Silent push: the shared zone changed → pull changes.
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        onRemoteChange?()
        return .newData
    }
}
