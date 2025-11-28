//
//  ClockOrchestrator.swift
//  GreenSquare
//

import Foundation

/// Represents the hand positions for a single clock
struct ClockHandPosition {
    var minuteHandDegrees: Float  // 0 = 12 o'clock, clockwise
    var hourHandDegrees: Float    // 0 = 12 o'clock, clockwise
    var minuteHandStep: Float = 0
    var hourHandStep: Float = 0

    static let noon = ClockHandPosition(minuteHandDegrees: 0, hourHandDegrees: 0)
    static let quarter = ClockHandPosition(minuteHandDegrees: 90, hourHandDegrees: 90)
    static let half = ClockHandPosition(minuteHandDegrees: 180, hourHandDegrees: 180)
}

/// Orchestrates the hand positions for a grid of clocks
class ClockOrchestrator {
    var paused: Bool = true
    var currentAnimationDurationInFrames: Int = 0
    let rows: Int
    let columns: Int

    /// Current hand positions for all clocks [row][col]
    private(set) var positions: [[ClockHandPosition]]
    private(set) var finalPositions: [[ClockHandPosition]]

    /// Frame counter for animations
    private var frameCount: Int = 0

    init(rows: Int, columns: Int) {
        self.rows = rows
        self.columns = columns

        // Initialize all clocks to noon position
        self.positions = Array(
            repeating: Array(repeating: ClockHandPosition.noon, count: columns),
            count: rows
        )
        self.finalPositions = Array(
            repeating: Array(repeating: ClockHandPosition.noon, count: columns),
            count: rows
        )

    }

    /// Set hand position for a specific clock
    func setPosition(row: Int, col: Int, position: ClockHandPosition) {
        guard row >= 0 && row < rows && col >= 0 && col < columns else { return }
        positions[row][col] = position
    }

    /// Set hand position for a specific clock by degrees
    func setPosition(row: Int, col: Int, minuteDeg: Float, hourDeg: Float) {
        setPosition(row: row, col: col, position: ClockHandPosition(
            minuteHandDegrees: minuteDeg,
            hourHandDegrees: hourDeg
        ))
    }

    /// Called every frame to update animation state
    /// Override this method in subclasses to implement custom animations
    func tick() {
        if paused {
            return
        }
        
        frameCount += 1
        
//        print(frameCount, currentAnimationDurationInFrames)
        
        if (frameCount == currentAnimationDurationInFrames) {
            paused = true
        }

        // Default animation: wave pattern across the grid
        for row in 0..<rows {
            for col in 0..<columns {
                let minuteAngle = positions[row][col].minuteHandDegrees + positions[row][col].minuteHandStep
                let hourAngle = positions[row][col].hourHandDegrees + positions[row][col].hourHandStep

                positions[row][col] = ClockHandPosition(
                    minuteHandDegrees: minuteAngle.truncatingRemainder(dividingBy: 360),
                    hourHandDegrees: hourAngle.truncatingRemainder(dividingBy: 360),
                    minuteHandStep: positions[row][col].minuteHandStep,
                    hourHandStep: positions[row][col].hourHandStep,
                )
            }
        }
    }

    /// Apply current positions to the clock grid view
    func applyToGrid(_ gridView: ClockGridView) {
        for row in 0..<rows {
            for col in 0..<columns {
                if let clock = gridView.clock(at: row, col: col) {
                    let pos = positions[row][col]
                    clock.setClockHands(minuteHandDeg: pos.minuteHandDegrees, hourHandDeg: pos.hourHandDegrees)
                }
            }
        }
    }

    /// Reset all clocks to 12 o'clock position
    func resetToNoon() {
        for row in 0..<rows {
            for col in 0..<columns {
                positions[row][col] = ClockHandPosition.noon
            }
        }
    }
    
    func setEndPosition(number: Int, durationInFrames: Int) {
        let digitOnePositions = [
            [[225, 225],  [180, 180]],
            [[225, 225],  [0, 180]],
            [[225, 225],  [0, 0]],
        ]
        
        for row in 0..<rows {
            for col in 0..<columns {
                let hourHandDistanceInDeg = Float(digitOnePositions[row][col][0]) - positions[row][col].hourHandDegrees;
                let minuteHandDistanceInDeg = Float(digitOnePositions[row][col][1]) - positions[row][col].minuteHandDegrees;

                positions[row][col].hourHandStep = hourHandDistanceInDeg / Float(durationInFrames)
                positions[row][col].minuteHandStep = minuteHandDistanceInDeg / Float(durationInFrames)
            }
        }
        frameCount = 0
        currentAnimationDurationInFrames = durationInFrames
        paused = false
    }
    
    func pause() {
        paused = true
    }
    
    func play() {
        paused = false
    }
}
