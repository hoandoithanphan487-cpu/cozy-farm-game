//
//  CreekSproutApp.swift
//  CreekSprout
//
//  Created by 冯一帆 on 2026/8/13.
//

import SwiftUI

@main
struct CreekSproutApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 960, minHeight: 640)
        }
        .defaultSize(width: 1280, height: 800)
        .windowResizability(.contentMinSize)
    }
}
