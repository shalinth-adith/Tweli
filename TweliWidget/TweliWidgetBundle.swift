//
//  TweliWidgetBundle.swift
//  TweliWidget
//

import WidgetKit
import SwiftUI

@main
struct TweliWidgetBundle: WidgetBundle {
    var body: some Widget {
        CountdownWidget()
        PartnerMoodWidget()
        NextDateWidget()
        LastPingWidget()
    }
}
