//
//  ContentView.swift
//  CreekSprout
//
//  Created by 冯一帆 on 2026/8/13.
//

import SpriteKit
import SwiftUI

struct ContentView: View {
    @FocusState private var isSceneFocused: Bool
    @State private var farmScene = FarmScene.makeDefault()
    @State private var coordinateCaption = GameState.spikeDefault.coordinateCaption

    var body: some View {
        ZStack(alignment: .top) {
            SpriteView(scene: farmScene)
                .ignoresSafeArea()
                .focusable()
                .focused($isSceneFocused)
                .focusEffectDisabled()

            Text(coordinateCaption)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.top, 10)
                .allowsHitTesting(false)
        }
        .onAppear {
            isSceneFocused = true
            coordinateCaption = farmScene.gameState.coordinateCaption
        }
        .onKeyPress(phases: .down) { press in
            guard let direction = Self.direction(for: press) else {
                return .ignored
            }
            farmScene.tryMove(direction)
            coordinateCaption = farmScene.gameState.coordinateCaption
            return .handled
        }
    }

    private static func direction(for press: KeyPress) -> Direction? {
        let character = press.characters.lowercased()
        if press.key == .leftArrow || character == "a" {
            return .left
        }
        if press.key == .rightArrow || character == "d" {
            return .right
        }
        if press.key == .downArrow || character == "s" {
            return .down
        }
        if press.key == .upArrow || character == "w" {
            return .up
        }
        return nil
    }
}

#Preview {
    ContentView()
}
