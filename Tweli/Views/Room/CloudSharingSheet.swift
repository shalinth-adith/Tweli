//
//  CloudSharingSheet.swift
//  Tweli
//
//  SwiftUI wrapper around UICloudSharingController — the native "invite partner"
//  share sheet backed by a real CKShare (no visible URL).
//

import SwiftUI
import CloudKit
import UIKit

struct CloudSharingSheet: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer
    var onComplete: () -> Void = {}

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onComplete: onComplete) }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let onComplete: () -> Void
        init(onComplete: @escaping () -> Void) { self.onComplete = onComplete }

        func itemTitle(for csc: UICloudSharingController) -> String? { "Tweli" }

        func cloudSharingController(_ csc: UICloudSharingController,
                                    failedToSaveShareWithError error: Error) {
            print("[CloudKit] share sheet failed: \(error.localizedDescription)")
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) { onComplete() }
        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {}
    }
}

/// Fallback share sheet for plain items (invite link text) when CloudKit is off.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
