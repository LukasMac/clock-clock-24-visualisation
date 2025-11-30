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
    var startMinuteHandDegrees: Float = 0
    var startHourHandDegrees: Float = 0

    static let noon = ClockHandPosition(minuteHandDegrees: 0, hourHandDegrees: 0, startMinuteHandDegrees: 0, startHourHandDegrees: 0)
    static let quarter = ClockHandPosition(minuteHandDegrees: 90, hourHandDegrees: 90, startMinuteHandDegrees: 90, startHourHandDegrees: 90)
    static let half = ClockHandPosition(minuteHandDegrees: 180, hourHandDegrees: 180, startMinuteHandDegrees: 180, startHourHandDegrees: 180)
}

let digitsPositions: [[[[Float]]]] = [
    [
        // ZERO
        [[90, 180],  [180, 270]],
        [[0, 180],  [0, 180]],
        [[0, 90],  [0, 270]],
    ],

    [
        // ONE
        [[225, 225],  [270, 180]],
        [[225, 225],  [0, 180]],
        [[225, 225],  [0, 0]],
    ],

    [
        // TWO
        [[90, 90],  [270, 180]],
        [[180, 90],  [0, 270]],
        [[0, 90],  [270, 270]],
    ],

    [
        // THREE
        [[90, 90],  [270, 180]],
        [[90, 90],  [0, 270]],
        [[90, 90],  [0, 270]],
    ],

    [
        // FOUR
        [[180, 180],  [180, 180]],
        [[0, 90],  [0, 180]],
        [[225, 225],  [0, 0]],
    ],

    [
        // FIVE
        [[90, 180],  [270, 270]],
        [[0, 90],  [270, 180]],
        [[90, 90],  [0, 270]],
    ],

    [
        // SIX
        [[90, 180],  [270, 270]],
        [[0, 180],  [270, 180]],
        [[0, 90],  [0, 270]],
    ],

    [
        // SEVEN
        [[90, 90],  [270, 180]],
        [[225, 225],  [0, 180]],
        [[225, 225],  [0, 0]],
    ],

    [
        // EIGHT
        [[90, 180],  [270, 180]],
        [[0, 90],  [270, 0]],
        [[0, 90],  [0, 270]],
    ],

    [
        // NINE
        [[90, 180],  [270, 180]],
        [[0, 90],  [0, 180]],
        [[90, 90],  [0, 270]],
    ]
]

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

    /// Ease-in-out function: -(cos(π * x) - 1) / 2
    private func easeInOut(_ x: Float) -> Float {
        return -(cos(.pi * x) - 1) / 2
    }

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
        positions[row][col] = ClockHandPosition(
            minuteHandDegrees: position.minuteHandDegrees,
            hourHandDegrees: position.hourHandDegrees,
            minuteHandStep: position.minuteHandStep,
            hourHandStep: position.hourHandStep,
            startMinuteHandDegrees: position.minuteHandDegrees,
            startHourHandDegrees: position.hourHandDegrees
        )
    }

    /// Set hand position for a specific clock by degrees
    func setPosition(row: Int, col: Int, minuteDeg: Float, hourDeg: Float) {
        setPosition(row: row, col: col, position: ClockHandPosition(
            minuteHandDegrees: minuteDeg,
            hourHandDegrees: hourDeg,
            startMinuteHandDegrees: minuteDeg,
            startHourHandDegrees: hourDeg
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

        // Default animation: wave pattern across the grid with easing
        let progress = Float(frameCount) / Float(currentAnimationDurationInFrames)
        let easedProgress = easeInOut(progress)

        for row in 0..<rows {
            for col in 0..<columns {
                // Calculate target positions (start + total distance)
                let targetMinuteAngle = positions[row][col].startMinuteHandDegrees + (positions[row][col].minuteHandStep * Float(currentAnimationDurationInFrames))
                let targetHourAngle = positions[row][col].startHourHandDegrees + (positions[row][col].hourHandStep * Float(currentAnimationDurationInFrames))

                // Interpolate between start and target using eased progress
                let minuteAngle = positions[row][col].startMinuteHandDegrees + (targetMinuteAngle - positions[row][col].startMinuteHandDegrees) * easedProgress
                let hourAngle = positions[row][col].startHourHandDegrees + (targetHourAngle - positions[row][col].startHourHandDegrees) * easedProgress

                positions[row][col] = ClockHandPosition(
                    minuteHandDegrees: minuteAngle.truncatingRemainder(dividingBy: 360),
                    hourHandDegrees: hourAngle.truncatingRemainder(dividingBy: 360),
                    minuteHandStep: positions[row][col].minuteHandStep,
                    hourHandStep: positions[row][col].hourHandStep,
                    startMinuteHandDegrees: positions[row][col].startMinuteHandDegrees,
                    startHourHandDegrees: positions[row][col].startHourHandDegrees
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
        print("setEndPosition", number, durationInFrames)

        for row in 0..<rows {
            for col in 0..<columns {
                // Each pair of columns represents a digit;
                // extract the correct digit for this column pair
                let digitIndex = col / 2
                let digit = (number / Int(pow(10.0, Double(3 - digitIndex)))) % 10
                let digitPositions = digitsPositions[digit]
                let column = col % 2

                let hourHandDistanceInDeg = digitPositions[row][column][0] - positions[row][col].hourHandDegrees;
                let minuteHandDistanceInDeg = digitPositions[row][column][1] - positions[row][col].minuteHandDegrees;

                // Store the starting positions for easing
                positions[row][col].startMinuteHandDegrees = positions[row][col].minuteHandDegrees
                positions[row][col].startHourHandDegrees = positions[row][col].hourHandDegrees

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
