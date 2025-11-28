//
//  ClockScreenSaverView.swift
//  GreenSquare
//
//  Created by Robert Tolar Haining on 4/9/20.
//  Copyright © 2020 Robert Tolar Haining. All rights reserved.
//

import Foundation
import ScreenSaver

class ClockScreenSaverView: ScreenSaverView {
    let clockGridView = ClockGridView(frame: .zero)
    let orchestrator = ClockOrchestrator(rows: ClockGridView.rows, columns: ClockGridView.columns)

    private var lastMinute: Int = -1
    private var frameCount: Int = 0
    private let checkIntervalFrames: Int = 120 // Check every 2 seconds at 60 FPS

    override init?(frame: CGRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        self.animationTimeInterval = 1 / 60.0
        addSubview(clockGridView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func startAnimation() {
        super.startAnimation()
    }

    override func stopAnimation() {
        super.stopAnimation()
    }

    override func draw(_ rect: NSRect) {
        super.draw(rect)
        clockGridView.frame = rect
    }

    override func animateOneFrame() {
        frameCount += 1

        // Only check for minute changes every 2 seconds (120 frames at 60 FPS)
        if frameCount % checkIntervalFrames == 0 {
            let currentMinute = Calendar.current.component(.minute, from: Date())
            if currentMinute != lastMinute {
                lastMinute = currentMinute
                let date = Date()
                let calendar = Calendar.current
                let hour = calendar.component(.hour, from: date)
                let minute = calendar.component(.minute, from: date)
                // Ensure HH and MM are always two digits
                let hh = String(format: "%02d", hour)
                let mm = String(format: "%02d", minute)
                let hhmmString = hh + mm
                if let hhmm = Int(hhmmString) {
                    orchestrator.setEndPosition(number: hhmm, durationInFrames: 9 * 10)
                }
            }
        }

        orchestrator.tick()
        orchestrator.applyToGrid(clockGridView)
    }

    /// Reset all clocks to 12 o'clock position
    func resetToNoon() {
        orchestrator.resetToNoon()
        orchestrator.applyToGrid(clockGridView)
    }
    
    func test(digit: Int) {
        orchestrator.setEndPosition(number: digit, durationInFrames: 9 * 10)
    }
}
