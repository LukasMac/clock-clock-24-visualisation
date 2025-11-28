//
//  ClockGridView.swift
//  GreenSquare
//

import AppKit
import RealityKit

class ClockGridView: NSView {
    static let columns = 8
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
        arView.environment.background = .color(.init(red: 0.85, green: 0.84, blue: 0.82, alpha: 1.0))
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

        // Add wall behind the clocks for them to "hang" on
        // Make it large enough that edges are never visible
        let wallSize: Float = 100.0
        let wallMesh = MeshResource.generatePlane(width: wallSize, height: wallSize)
        var wallMaterial = SimpleMaterial()
        wallMaterial.color = .init(tint: .init(red: 0.94, green: 0.93, blue: 0.91, alpha: 1.0), texture: nil)
        wallMaterial.roughness = .init(floatLiteral: 0.9)
        wallMaterial.metallic = .init(floatLiteral: 0.0)
        let wall = ModelEntity(mesh: wallMesh, materials: [wallMaterial])
        // Position wall behind the clocks (negative z) and rotate to face camera
        wall.position = [0, 0, -0.5]
        wall.transform.rotation = simd_quatf(angle: 0, axis: [0, 1, 0])
        anchor.addChild(wall)

        // Add frame boxes around the clock grid to create margins
        let frameThickness: Float = 0.3
        let frameDepth: Float = 0.5
        let frameMargin: Float = 1.2  // Distance from edge clocks to frame
        let frameLength: Float = 50.0  // Long enough to extend beyond view

        var frameMaterial = SimpleMaterial()
        frameMaterial.color = .init(tint: .init(red: 0.25, green: 0.22, blue: 0.2, alpha: 1.0), texture: nil)
        frameMaterial.roughness = .init(floatLiteral: 0.7)
        frameMaterial.metallic = .init(floatLiteral: 0.1)

        // // Top frame
        // let topFrameMesh = MeshResource.generateBox(width: frameLength, height: frameThickness, depth: frameDepth)
        // let topFrame = ModelEntity(mesh: topFrameMesh, materials: [frameMaterial])
        // topFrame.position = [0, gridHeight / 2 + frameMargin, 0]
        // anchor.addChild(topFrame)

        // // Bottom frame
        // let bottomFrame = ModelEntity(mesh: topFrameMesh, materials: [frameMaterial])
        // bottomFrame.position = [0, -gridHeight / 2 - frameMargin, 0]
        // anchor.addChild(bottomFrame)

        // // Left frame
        // let sideFrameMesh = MeshResource.generateBox(width: frameThickness, height: frameLength, depth: frameDepth)
        // let leftFrame = ModelEntity(mesh: sideFrameMesh, materials: [frameMaterial])
        // leftFrame.position = [-gridWidth / 2 - frameMargin, 0, 0]
        // anchor.addChild(leftFrame)

        // // Right frame
        // let rightFrame = ModelEntity(mesh: sideFrameMesh, materials: [frameMaterial])
        // rightFrame.position = [gridWidth / 2 + frameMargin, 0, 0]
        // anchor.addChild(rightFrame)

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
        guard let url = Bundle.main.url(forResource: "box_with_cutout_5", withExtension: "usdz") else {
            print("USDZ file not found in bundle")
            return nil
        }
        return try? ModelEntity.loadModel(contentsOf: url)
    }

    private func setupCamera() {
        // Calculate camera distance based on grid size
        let gridWidth = Float(ClockGridView.columns) * clockSpacing
        let gridHeight = Float(ClockGridView.rows) * clockSpacing
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
