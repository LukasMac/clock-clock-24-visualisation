//
//  ClockGridView.swift
//  GreenSquare
//

import AppKit

class ClockGridView: NSView {
    static let columns = 9
    static let rows = 3
    static let margin: CGFloat = 40

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
        let margin = ClockGridView.margin
        let availableWidth = bounds.width - (margin * 2)
        let availableHeight = bounds.height - (margin * 2)

        // Calculate cell size as perfect square
        let maxCellWidth = availableWidth / CGFloat(ClockGridView.columns)
        let maxCellHeight = availableHeight / CGFloat(ClockGridView.rows)
        let cellSize = min(maxCellWidth, maxCellHeight)

        // Calculate total grid size and offset to center it
        let gridWidth = cellSize * CGFloat(ClockGridView.columns)
        let gridHeight = cellSize * CGFloat(ClockGridView.rows)
        let offsetX = margin + (availableWidth - gridWidth) / 2
        let offsetY = margin + (availableHeight - gridHeight) / 2

        for row in 0..<ClockGridView.rows {
            for col in 0..<ClockGridView.columns {
                let x = offsetX + CGFloat(col) * cellSize
                let y = offsetY + (gridHeight - CGFloat(row + 1) * cellSize) // Top-to-bottom
                clocks[row][col].frame = CGRect(x: x, y: y, width: cellSize, height: cellSize)
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
