//
//  TweliWidgetBundle.swift
//  TweliWidget
//

import WidgetKit
import SwiftUI

@main
struct TweliWidgetBundle: WidgetBundle {
    // Comp C1: one widget, not four. The thread carries the countdown, the mood
    // carries the message — everything the old Countdown / NextDate / LastPing
    // widgets said separately now lives on this single face.
    var body: some Widget {
        TwoOfUsWidget()
    }
}
