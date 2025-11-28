//
//  ClockGridView.swift
//  GreenSquare
//

import AppKit
import RealityKit

class ClockGridView: NSView {
    static let columns = 2
    static let rows = 3

    private var arView: ARView!
    private var clocks: [[ClockEntity]] = []
    private var anchor: AnchorEntity!

    // Spacing between clocks in 3D space
    private let clockSpacing: Float = 2;

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupScene()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupScene() {
        // Create single ARView for entire grid
        arView = ARView(frame: bounds)
        arView.autoresizingMask = [.width, .height]
        arView.environment.background = .color(.white)
        addSubview(arView)

        // Create anchor
        anchor = AnchorEntity(world: .zero)
        arView.scene.addAnchor(anchor)

        // Load model template once
        let modelTemplate = loadModelTemplate()

        // Calculate grid center offset
        let gridWidth = Float(ClockGridView.columns - 1) * clockSpacing
        let gridHeight = Float(ClockGridView.rows - 1) * clockSpacing
        let startX = -gridWidth / 2
        let startY = gridHeight / 2

        // Create clock entities in a grid
        for row in 0..<ClockGridView.rows {
            var rowClocks: [ClockEntity] = []
            for col in 0..<ClockGridView.columns {
                let clock = ClockEntity(modelTemplate: modelTemplate)

                // Position in 3D grid
                let x = startX + Float(col) * clockSpacing
                let y = startY - Float(row) * clockSpacing
                let z: Float = 0
                clock.position = [x, y, z]

                anchor.addChild(clock)
                rowClocks.append(clock)
            }
            clocks.append(rowClocks)
        }

        // Add single directional light for uniform lighting
        let directionalLight = DirectionalLight()
        directionalLight.light.intensity = 1500
        directionalLight.light.color = .white
        directionalLight.look(at: [0, 0, 0], from: [2, 3, 10], relativeTo: nil)
        anchor.addChild(directionalLight)

        // Position camera to view entire grid
        setupCamera()

        // Set environment lighting
        arView.environment.lighting.intensityExponent = 1.0
    }

    private func loadModelTemplate() -> ModelEntity? {
        guard let url = Bundle.main.url(forResource: "box_with_cutout_3", withExtension: "usdz") else {
            print("USDZ file not found in bundle")
            return nil
        }
        return try? ModelEntity.loadModel(contentsOf: url)
    }

    private func setupCamera() {
        // Calculate camera distance based on grid size
        let gridWidth = Float(ClockGridView.columns) * clockSpacing * 2
        let gridHeight = Float(ClockGridView.rows) * clockSpacing * 2
        let maxDimension = max(gridWidth, gridHeight)

        // Camera distance to fit the grid (using rough FOV estimate)
        let cameraDistance = maxDimension * 0.9

        // Create perspective camera
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 60
        camera.position = [0, 0, cameraDistance]
        camera.look(at: [0, 0, 0], from: camera.position, relativeTo: nil)
        anchor.addChild(camera)
    }

    /// Get a clock at a specific grid position
    func clock(at row: Int, col: Int) -> ClockEntity? {
        guard row >= 0 && row < ClockGridView.rows && col >= 0 && col < ClockGridView.columns else {
            return nil
        }
        return clocks[row][col]
    }
}
