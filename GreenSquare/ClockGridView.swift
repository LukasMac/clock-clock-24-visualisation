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

        // Add ground plane for shadows to fall on
        let groundSize: Float = 20.0
        let groundMesh = MeshResource.generatePlane(width: groundSize, depth: groundSize)
        var groundMaterial = SimpleMaterial()
        groundMaterial.color = .init(tint: .init(white: 0.95, alpha: 1.0), texture: nil)
        groundMaterial.roughness = .init(floatLiteral: 0.8)
        groundMaterial.metallic = .init(floatLiteral: 0.0)
        let groundPlane = ModelEntity(mesh: groundMesh, materials: [groundMaterial])
        groundPlane.position = [0, -gridHeight / 2 - 1.5, -2]
        groundPlane.transform.rotation = simd_quatf(angle: -.pi / 6, axis: [1, 0, 0])
        anchor.addChild(groundPlane)

        // Main directional light (key light) - simulates sunlight from upper right
        let keyLight = DirectionalLight()
        keyLight.light.intensity = 1200
        keyLight.light.color = .init(white: 1.0, alpha: 1.0)
        keyLight.look(at: [0, 0, 0], from: [3, 4, 8], relativeTo: nil)
        // Enable shadow casting
        keyLight.shadow = DirectionalLightComponent.Shadow(
            maximumDistance: 15,
            depthBias: 0.03
        )
        anchor.addChild(keyLight)

        // Fill light - softer light from opposite side to reduce harsh shadows
        let fillLight = DirectionalLight()
        fillLight.light.intensity = 400
        fillLight.light.color = .init(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0)
        fillLight.look(at: [0, 0, 0], from: [-4, 2, 6], relativeTo: nil)
        anchor.addChild(fillLight)

        // Position camera to view entire grid
        setupCamera()

        // Set environment lighting for ambient illumination
        arView.environment.lighting.intensityExponent = 0.8
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
