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

    // Store references for real-time updates
    private var keyLight: DirectionalLight!
    private var fillLight: DirectionalLight!
    private var rimLight: DirectionalLight!
    private var wall: ModelEntity!
    private var frameEntities: [ModelEntity] = []
    private var controlPanel: NSView!

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
        // Black background - lighting will illuminate the scene
        arView.environment.background = .color(.black)
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
        // Wall material - medium gray to match background
        var wallMaterial = SimpleMaterial()
        wallMaterial.color = .init(tint: .init(red: 0.816, green: 0.816, blue: 0.816, alpha: 1.0), texture: nil)
        wallMaterial.roughness = .init(floatLiteral: 0.9)
        wallMaterial.metallic = .init(floatLiteral: 0.0)
        wall = ModelEntity(mesh: wallMesh, materials: [wallMaterial])
        // Position wall behind the clocks (negative z) and rotate to face camera
        wall.position = [0, 0, -0.5]
        wall.transform.rotation = simd_quatf(angle: 0, axis: [0, 1, 0])
        anchor.addChild(wall)

        // Add frame boxes around the clock grid to create margins
        let frameThickness: Float = 1
        let frameDepth: Float = 0.5
        let frameMargin: Float = 1.5  // Distance from edge clocks to frame

        // Frame material - slightly glossy white (roughness 0.2 for subtle reflections)
        var frameMaterial = SimpleMaterial()
        frameMaterial.color = .init(tint: .white, texture: nil)
        frameMaterial.roughness = .init(floatLiteral: 0.2)
        frameMaterial.metallic = .init(floatLiteral: 0.0)

        // Top frame
        let topFrameMesh = MeshResource.generateBox(width: Float(ClockGridView.columns * 2), height: frameThickness, depth: frameDepth)
        let topFrame = ModelEntity(mesh: topFrameMesh, materials: [frameMaterial])
        topFrame.position = [0, gridHeight / 2 + frameMargin, 0.75]
        anchor.addChild(topFrame)
        frameEntities.append(topFrame)

        // Bottom frame
        let bottomFrame = ModelEntity(mesh: topFrameMesh, materials: [frameMaterial])
        bottomFrame.position = [0, -gridHeight / 2 - frameMargin, 0.75]
        anchor.addChild(bottomFrame)
        frameEntities.append(bottomFrame)

        // Left frame
        let sideFrameMesh = MeshResource.generateBox(width: frameThickness, height: Float(ClockGridView.rows * 2) + (frameThickness * 2), depth: frameDepth)
        let leftFrame = ModelEntity(mesh: sideFrameMesh, materials: [frameMaterial])
        leftFrame.position = [-gridWidth / 2 - frameMargin, 0, 0.75]
        anchor.addChild(leftFrame)
        frameEntities.append(leftFrame)

        // Right frame
        let rightFrame = ModelEntity(mesh: sideFrameMesh, materials: [frameMaterial])
        rightFrame.position = [gridWidth / 2 + frameMargin, 0, 0.75]
        anchor.addChild(rightFrame)
        frameEntities.append(rightFrame)

        // 1. Main Key Light - Bottom-right, creates gradient: white (bottom-right) to dark (top-left)
        // Slightly warm white (approx 6000K)
        keyLight = DirectionalLight()
        keyLight.light.intensity = 1200
        keyLight.light.color = .init(red: 1.0, green: 0.98, blue: 0.95, alpha: 1.0)
        // Position: bottom-right, angled to create gradient on wall toward top-left
        keyLight.look(at: [-5, 3, 0], from: [12, -6, 8], relativeTo: nil)
        // Enable soft shadow casting
        keyLight.shadow = DirectionalLightComponent.Shadow(
            maximumDistance: 20,
            depthBias: 0.1
        )
        anchor.addChild(keyLight)

        // 2. Soft Fill Light - Frontal, provides general illumination
        // Lower intensity to maintain the gradient effect
        fillLight = DirectionalLight()
        fillLight.light.intensity = 300
        fillLight.light.color = .init(red: 0.95, green: 0.98, blue: 1.0, alpha: 1.0)
        // Position: frontal, slightly from below-right to enhance gradient
        fillLight.look(at: [0, 0, 0], from: [5, -2, 12], relativeTo: nil)
        anchor.addChild(fillLight)

        // 3. Subtle Rim/Edge Light - Back-left, very low intensity
        // Adds slight definition to top-left area without breaking gradient
        rimLight = DirectionalLight()
        rimLight.light.intensity = 50
        rimLight.light.color = .init(white: 1.0, alpha: 1.0)
        // Position: back-left
        rimLight.look(at: [0, 0, 0], from: [-8, 4, -5], relativeTo: nil)
        anchor.addChild(rimLight)

        // Position camera to view entire grid
        setupCamera()

        // Disable default environment/IBL lighting completely so scene is black without lights
        // Use a very negative exponent to effectively disable IBL
        arView.environment.lighting.intensityExponent = -10.0
        arView.environment.lighting.resource = nil

        // Setup control panel for adjusting lighting
        setupControlPanel()
    }

    // MARK: - Control Panel

    private func setupControlPanel() {
        let panelWidth: CGFloat = 280
        let panelHeight: CGFloat = 920
        controlPanel = NSView(frame: NSRect(x: 10, y: 10, width: panelWidth, height: panelHeight))
        controlPanel.wantsLayer = true
        controlPanel.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.7).cgColor
        controlPanel.layer?.cornerRadius = 8
        addSubview(controlPanel)

        var yOffset: CGFloat = panelHeight - 30

        // Title
        let title = createLabel("Lighting Controls", bold: true)
        title.frame = NSRect(x: 10, y: yOffset, width: panelWidth - 20, height: 20)
        controlPanel.addSubview(title)
        yOffset -= 30

        // Key Light Section (bottom-right, creates gradient)
        yOffset = addSectionHeader("Key Light (gradient source)", at: yOffset)
        yOffset = addSlider("Intensity", min: 0, max: 2000, value: 1200, tag: 1, at: yOffset)
        yOffset = addSlider("Pos X", min: -15, max: 20, value: 12, tag: 2, at: yOffset)
        yOffset = addSlider("Pos Y", min: -15, max: 15, value: -6, tag: 3, at: yOffset)
        yOffset = addSlider("Pos Z", min: 1, max: 20, value: 8, tag: 4, at: yOffset)
        yOffset = addSlider("Rot X", min: -180, max: 180, value: 0, tag: 6, at: yOffset)
        yOffset = addSlider("Rot Y", min: -180, max: 180, value: 0, tag: 7, at: yOffset)
        yOffset = addSlider("Rot Z", min: -180, max: 180, value: 0, tag: 8, at: yOffset)
        yOffset = addSlider("Shadow Bias", min: 0.01, max: 0.3, value: 0.1, tag: 5, at: yOffset)

        // Fill Light Section (frontal, soft)
        yOffset -= 10
        yOffset = addSectionHeader("Fill Light (frontal)", at: yOffset)
        yOffset = addSlider("Intensity", min: 0, max: 1000, value: 300, tag: 10, at: yOffset)
        yOffset = addSlider("Pos X", min: -15, max: 15, value: 5, tag: 11, at: yOffset)
        yOffset = addSlider("Pos Y", min: -10, max: 15, value: -2, tag: 12, at: yOffset)

        // Rim Light Section (back-left, subtle)
        yOffset -= 10
        yOffset = addSectionHeader("Rim Light (back-left)", at: yOffset)
        yOffset = addSlider("Intensity", min: 0, max: 500, value: 50, tag: 40, at: yOffset)
        yOffset = addSlider("Pos X", min: -15, max: 15, value: -8, tag: 41, at: yOffset)
        yOffset = addSlider("Pos Y", min: -10, max: 10, value: 4, tag: 42, at: yOffset)

        // Material Section (applies to frames and clocks)
        yOffset -= 10
        yOffset = addSectionHeader("Material (Frame + Clocks)", at: yOffset)
        yOffset = addSlider("Roughness", min: 0, max: 1, value: 0.2, tag: 20, at: yOffset)
        yOffset = addSlider("Metallic", min: 0, max: 1, value: 0, tag: 21, at: yOffset)

        // Environment
        yOffset -= 10
        yOffset = addSectionHeader("Environment", at: yOffset)
        yOffset = addSlider("Ambient", min: 0, max: 2, value: 0, tag: 30, at: yOffset)

        // Print button
        let printButton = NSButton(frame: NSRect(x: 10, y: 10, width: panelWidth - 20, height: 24))
        printButton.title = "Print Current Values"
        printButton.bezelStyle = .rounded
        printButton.target = self
        printButton.action = #selector(printCurrentValues)
        controlPanel.addSubview(printButton)
    }

    private func createLabel(_ text: String, bold: Bool = false) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.textColor = .white
        label.font = bold ? NSFont.boldSystemFont(ofSize: 12) : NSFont.systemFont(ofSize: 10)
        return label
    }

    private func addSectionHeader(_ text: String, at y: CGFloat) -> CGFloat {
        let label = createLabel(text, bold: true)
        label.frame = NSRect(x: 10, y: y, width: 260, height: 16)
        controlPanel.addSubview(label)
        return y - 20
    }

    private func addSlider(_ name: String, min: Double, max: Double, value: Double, tag: Int, at y: CGFloat) -> CGFloat {
        let label = createLabel("\(name): \(String(format: "%.2f", value))")
        label.frame = NSRect(x: 10, y: y, width: 260, height: 14)
        label.tag = tag + 1000  // Use offset for label tags
        controlPanel.addSubview(label)

        let slider = NSSlider(value: value, minValue: min, maxValue: max, target: self, action: #selector(sliderChanged(_:)))
        slider.frame = NSRect(x: 10, y: y - 18, width: 260, height: 20)
        slider.tag = tag
        controlPanel.addSubview(slider)

        return y - 38
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        let value = sender.floatValue

        // Update label
        if let label = controlPanel.viewWithTag(sender.tag + 1000) as? NSTextField {
            let name = label.stringValue.components(separatedBy: ":").first ?? ""
            label.stringValue = "\(name): \(String(format: "%.2f", value))"
        }

        switch sender.tag {
        // Key Light
        case 1: keyLight.light.intensity = value
        case 2, 3, 4, 6, 7, 8: updateKeyLightPosition()
        case 5:
            keyLight.shadow = DirectionalLightComponent.Shadow(
                maximumDistance: 20,
                depthBias: value
            )

        // Fill Light
        case 10: fillLight.light.intensity = value
        case 11, 12: updateFillLightPosition()

        // Rim Light
        case 40: rimLight.light.intensity = value
        case 41, 42: updateRimLightPosition()

        // Frame Material
        case 20, 21: updateFrameMaterial()

        // Environment
        case 30: arView.environment.lighting.intensityExponent = value

        default: break
        }
    }

    private func updateKeyLightPosition() {
        guard let xSlider = controlPanel.viewWithTag(2) as? NSSlider,
              let ySlider = controlPanel.viewWithTag(3) as? NSSlider,
              let zSlider = controlPanel.viewWithTag(4) as? NSSlider,
              let rotXSlider = controlPanel.viewWithTag(6) as? NSSlider,
              let rotYSlider = controlPanel.viewWithTag(7) as? NSSlider,
              let rotZSlider = controlPanel.viewWithTag(8) as? NSSlider else { return }

        let pos: SIMD3<Float> = [xSlider.floatValue, ySlider.floatValue, zSlider.floatValue]

        // First set position by looking at center
        keyLight.look(at: [0, 0, 0], from: pos, relativeTo: nil)

        // Then apply additional rotation around each axis (in radians)
        let rotX = rotXSlider.floatValue * .pi / 180.0
        let rotY = rotYSlider.floatValue * .pi / 180.0
        let rotZ = rotZSlider.floatValue * .pi / 180.0

        // Combine rotations: apply additional rotation on top of look-at rotation
        let additionalRotation = simd_quatf(angle: rotX, axis: [1, 0, 0]) *
                                  simd_quatf(angle: rotY, axis: [0, 1, 0]) *
                                  simd_quatf(angle: rotZ, axis: [0, 0, 1])
        keyLight.transform.rotation = keyLight.transform.rotation * additionalRotation
    }

    private func updateFillLightPosition() {
        guard let xSlider = controlPanel.viewWithTag(11) as? NSSlider,
              let ySlider = controlPanel.viewWithTag(12) as? NSSlider else { return }

        let pos: SIMD3<Float> = [xSlider.floatValue, ySlider.floatValue, 12]
        fillLight.look(at: [0, 0, 0], from: pos, relativeTo: nil)
    }

    private func updateRimLightPosition() {
        guard let xSlider = controlPanel.viewWithTag(41) as? NSSlider,
              let ySlider = controlPanel.viewWithTag(42) as? NSSlider else { return }

        let pos: SIMD3<Float> = [xSlider.floatValue, ySlider.floatValue, -5]
        rimLight.look(at: [0, 0, 0], from: pos, relativeTo: nil)
    }

    private func updateFrameMaterial() {
        guard let roughnessSlider = controlPanel.viewWithTag(20) as? NSSlider,
              let metallicSlider = controlPanel.viewWithTag(21) as? NSSlider else { return }

        let roughness = roughnessSlider.floatValue
        let metallic = metallicSlider.floatValue

        var material = SimpleMaterial()
        material.color = .init(tint: .white, texture: nil)
        material.roughness = .init(floatLiteral: roughness)
        material.metallic = .init(floatLiteral: metallic)

        // Update frame entities
        for entity in frameEntities {
            entity.model?.materials = [material]
        }

        // Update clock entities with the same material
        for row in clocks {
            for clock in row {
                clock.updateMaterial(roughness: roughness, metallic: metallic)
            }
        }
    }

    @objc private func printCurrentValues() {
        print("\n// === CURRENT LIGHTING VALUES ===")
        print("keyLight.light.intensity = \((controlPanel.viewWithTag(1) as? NSSlider)?.floatValue ?? 0)")
        print("keyLight position: [\((controlPanel.viewWithTag(2) as? NSSlider)?.floatValue ?? 0), \((controlPanel.viewWithTag(3) as? NSSlider)?.floatValue ?? 0), \((controlPanel.viewWithTag(4) as? NSSlider)?.floatValue ?? 0)]")
        print("keyLight rotation (deg): [\((controlPanel.viewWithTag(6) as? NSSlider)?.floatValue ?? 0), \((controlPanel.viewWithTag(7) as? NSSlider)?.floatValue ?? 0), \((controlPanel.viewWithTag(8) as? NSSlider)?.floatValue ?? 0)]")
        print("keyLight shadow depthBias: \((controlPanel.viewWithTag(5) as? NSSlider)?.floatValue ?? 0)")
        print("fillLight.light.intensity = \((controlPanel.viewWithTag(10) as? NSSlider)?.floatValue ?? 0)")
        print("fillLight position: [\((controlPanel.viewWithTag(11) as? NSSlider)?.floatValue ?? 0), \((controlPanel.viewWithTag(12) as? NSSlider)?.floatValue ?? 0), 12]")
        print("rimLight.light.intensity = \((controlPanel.viewWithTag(40) as? NSSlider)?.floatValue ?? 0)")
        print("rimLight position: [\((controlPanel.viewWithTag(41) as? NSSlider)?.floatValue ?? 0), \((controlPanel.viewWithTag(42) as? NSSlider)?.floatValue ?? 0), -5]")
        print("material.roughness = \((controlPanel.viewWithTag(20) as? NSSlider)?.floatValue ?? 0)")
        print("material.metallic = \((controlPanel.viewWithTag(21) as? NSSlider)?.floatValue ?? 0)")
        print("environment.lighting.intensityExponent = \((controlPanel.viewWithTag(30) as? NSSlider)?.floatValue ?? 0)")
        print("// ================================\n")
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
