//
//  ClockOrchestrator.swift
//  GreenSquare
//

import Foundation

/// Represents the hand positions for a single clock
struct ClockHandPosition {
    var minuteHandDegrees: Float  // 0 = 12 o'clock, clockwise
    var hourHandDegrees: Float    // 0 = 12 o'clock, clockwise

    static let noon = ClockHandPosition(minuteHandDegrees: 0, hourHandDegrees: 0)
    static let quarter = ClockHandPosition(minuteHandDegrees: 90, hourHandDegrees: 90)
    static let half = ClockHandPosition(minuteHandDegrees: 180, hourHandDegrees: 180)
}

/// Orchestrates the hand positions for a grid of clocks
class ClockOrchestrator {
    let rows: Int
    let columns: Int

    /// Current hand positions for all clocks [row][col]
    private(set) var positions: [[ClockHandPosition]]

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
        frameCount += 1

        // Default animation: wave pattern across the grid
        for row in 0..<rows {
            for col in 0..<columns {
                let phase = Float(row * columns + col)
                let speed: Float = 1.0
                let minuteAngle = Float(frameCount) * speed + phase * 15
                let hourAngle = Float(frameCount) * (speed / 2) + phase * 10

                positions[row][col] = ClockHandPosition(
                    minuteHandDegrees: minuteAngle.truncatingRemainder(dividingBy: 360),
                    hourHandDegrees: hourAngle.truncatingRemainder(dividingBy: 360)
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
}
