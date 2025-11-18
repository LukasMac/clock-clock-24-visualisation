//
//  GreenSquareScreenSaverView.swift
//  GreenSquare
//
//  Created by Robert Tolar Haining on 4/9/20.
//  Copyright © 2020 Robert Tolar Haining. All rights reserved.
//

import Foundation
import ScreenSaver

class GreenSquareScreenSaverView: ScreenSaverView {
    let greenSquareView = GreenSquareView()
    
    override init?(frame: CGRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        self.animationTimeInterval = 1 / 120.0
        addSubview(greenSquareView)
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
        greenSquareView.frame = rect
    }

    override func animateOneFrame() {
       greenSquareView.rotateSphere(byDegrees: 1)
    }
}
