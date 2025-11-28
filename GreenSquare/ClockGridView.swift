//
//  ClockGridView.swift
//  GreenSquare
//

import AppKit

class ClockGridView: NSView {
    static let columns = 9
    static let rows = 3

    private(set) var clocks: [[ClockView]] = []

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupGrid()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupGrid() {
        for row in 0..<ClockGridView.rows {
            var rowClocks: [ClockView] = []
            for col in 0..<ClockGridView.columns {
                let clock = ClockView()
                addSubview(clock)
                rowClocks.append(clock)
            }
            clocks.append(rowClocks)
        }
    }

    override func layout() {
        super.layout()
        layoutClocks()
    }

    private func layoutClocks() {
        let cellWidth = bounds.width / CGFloat(ClockGridView.columns)
        let cellHeight = bounds.height / CGFloat(ClockGridView.rows)

        for row in 0..<ClockGridView.rows {
            for col in 0..<ClockGridView.columns {
                let x = CGFloat(col) * cellWidth
                let y = bounds.height - CGFloat(row + 1) * cellHeight // Top-to-bottom
                clocks[row][col].frame = CGRect(x: x, y: y, width: cellWidth, height: cellHeight)
            }
        }
    }

    /// Get a clock at a specific grid position
    func clock(at row: Int, col: Int) -> ClockView? {
        guard row >= 0 && row < ClockGridView.rows && col >= 0 && col < ClockGridView.columns else {
            return nil
        }
        return clocks[row][col]
    }
}
