//
//  ReplayBoard.swift
//  Hunch
//
//  Solve Replay (3.4), part 2: where each tile sits.
//
//  The board is a Sokoban-style grid. Tiles follow a snake path: left to right
//  on the first row, right to left on the next, and so on, so every slot is
//  one step from the one before it and Wick never has to jump across the
//  board. The grid picks the column count that gives the biggest square cells
//  that still fit the area, so a 4-guess solve gets big chunky tiles and a
//  200-guess grind still fits on one screen.
//
//  Pure geometry, no drawing: tested in HunchTests.
//

import CoreGraphics

nonisolated struct ReplayBoard: Equatable, Sendable {
    /// Slots on the board (tiles in the round).
    let count: Int
    let columns: Int
    let rows: Int
    /// Side of one square cell, in pixels.
    let cell: CGFloat
    /// Top-left corner of the grid.
    let origin: CGPoint

    init(count: Int, area: CGRect, maxCell: CGFloat = 200, maxColumns: Int = 24) {
        let n = max(1, count)
        var bestColumns = 1
        var bestRows = n
        var bestCell: CGFloat = -1
        for c in 1...max(1, min(maxColumns, n)) {
            let r = (n + c - 1) / c
            let size = min(area.width / CGFloat(c), area.height / CGFloat(r), maxCell)
            let better: Bool
            if size > bestCell + 0.5 {
                better = true
            } else if abs(size - bestCell) <= 0.5 {
                // Same cell size: prefer the squarer grid, then the wider one.
                let shape = abs(c - r), bestShape = abs(bestColumns - bestRows)
                better = shape < bestShape || (shape == bestShape && c > bestColumns)
            } else {
                better = false
            }
            if better {
                bestColumns = c
                bestRows = r
                bestCell = size
            }
        }
        let cell = max(1, bestCell.rounded(.down))
        self.count = n
        self.columns = bestColumns
        self.rows = bestRows
        self.cell = cell
        self.origin = CGPoint(x: (area.midX - CGFloat(bestColumns) * cell / 2).rounded(),
                              y: (area.midY - CGFloat(bestRows) * cell / 2).rounded())
    }

    /// The whole grid.
    var frame: CGRect {
        CGRect(x: origin.x, y: origin.y,
               width: CGFloat(columns) * cell, height: CGFloat(rows) * cell)
    }

    /// Row and column of a slot along the snake path.
    func position(of slot: Int) -> (row: Int, column: Int) {
        let row = slot / columns
        let i = slot % columns
        return (row, row % 2 == 0 ? i : columns - 1 - i)
    }

    func rect(of slot: Int) -> CGRect {
        let p = position(of: slot)
        return CGRect(x: origin.x + CGFloat(p.column) * cell,
                      y: origin.y + CGFloat(p.row) * cell,
                      width: cell, height: cell)
    }

    func center(of slot: Int) -> CGPoint {
        let r = rect(of: slot)
        return CGPoint(x: r.midX, y: r.midY)
    }
}
