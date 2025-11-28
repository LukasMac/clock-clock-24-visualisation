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
        orchestrator.tick()
        orchestrator.applyToGrid(clockGridView)
    }
}
