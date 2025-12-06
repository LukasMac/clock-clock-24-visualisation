//
//  ClockGridView.swift
//  GreenSquare
//

import AppKit
import RealityKit

// MARK: - Scene Configuration

struct SceneConfig {
    struct LightPosition {
        var intensity: Float
        var x: Float
        var y: Float
        var z: Float
        var rotX: Float
        var rotY: Float
        var rotZ: Float
    }

    struct SpotLightConfig {
        var position: LightPosition
        var innerAngle: Float
        var outerAngle: Float
    }

    struct ShadowConfig {
        var depthBias: Float
        var maxDistance: Float
    }

    struct MaterialConfig {
        var roughness: Float
        var metallic: Float
    }

    struct CameraConfig {
        var x: Float
        var y: Float
        var z: Float
        var rotX: Float
        var rotY: Float
        var rotZ: Float
        var fov: Float
    }

    var keyLight: LightPosition
    var keySpotLight: SpotLightConfig
    var shadow: ShadowConfig
    var fillLight: LightPosition
    var rimLight: LightPosition
    var clockMaterial: MaterialConfig
    var handMaterial: MaterialConfig
    var camera: CameraConfig
    var ambient: Float

    static let `default` = SceneConfig(
        keyLight: LightPosition(
            intensity: 165000,
            x: 13.97, y: 10.68, z: 4.33,
            rotX: -22.20, rotY: 30.25, rotZ: -44.09
        ),
        keySpotLight: SpotLightConfig(
            position: LightPosition(
                intensity: 7730000,  // SpotLight needs higher intensity due to attenuation
                x: 16.0, y: 21.5, z: 14.14,  // Further back than keyLight to cover scene with cone
                rotX: -32.20, rotY: 20.25, rotZ: -77.09
            ),
            innerAngle: 69.19,
            outerAngle: 115.89
        ),
        shadow: ShadowConfig(
            depthBias: 5.0,
            maxDistance: 9.51
        ),
        fillLight: LightPosition(
            intensity: 1087.83,
            x: -2.53, y: -4.55, z: 5.25,
            rotX: 0, rotY: 0, rotZ: 0
        ),
        rimLight: LightPosition(
            intensity: 373.97,
            x: -11.0, y: 6.46, z: -5,
            rotX: 0, rotY: 0, rotZ: 0
        ),
        clockMaterial: MaterialConfig(
            roughness: 0.8,
            metallic: 0.0
        ),
        handMaterial: MaterialConfig(
            roughness: 0.90,
            metallic: 0.20
        ),
        camera: CameraConfig(
            x: 0, y: 0, z: 14.4,  // Will be recalculated based on grid size
            rotX: 0, rotY: 0, rotZ: 0,
            fov: 60
        ),
        ambient: 0.0
    )
}

// Flipped NSView subclass for top-aligned content
private class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

class ClockGridView: NSView {

    // Scene configuration
    private let config = SceneConfig.default
    static let columns = 8
    static let rows = 3

    private var arView: ARView!
    private var clocks: [[ClockEntity]] = []
    private var anchor: AnchorEntity!

    // Store references for real-time updates
    private var keyLight: DirectionalLight!
    private var keySpotLight: SpotLight!
    private var useSpotLight: Bool = false  // Toggle for ray-traced shadows
    private var fillLight: DirectionalLight!
    private var rimLight: DirectionalLight!
    private var camera: PerspectiveCamera!
    private var wall: ModelEntity!
    private var frameEntities: [ModelEntity] = []
    private var controlWindow: NSWindow?

    // Spacing between clocks in 3D space
    // Slightly less than 2.0 to ensure clocks overlap and eliminate visible seams
    private let clockSpacing: Float = 1.85

    // Whether to show debug controls (only in Preview app)
    private let showControls: Bool

    convenience override init(frame: NSRect) {
        self.init(frame: frame, showControls: false)
    }

    init(frame: NSRect, showControls: Bool) {
        self.showControls = showControls
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
        let gridWidth = Float(ClockGridView.columns-1) * clockSpacing
        let gridHeight = Float(ClockGridView.rows-1) * clockSpacing
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
                clock.updateMaterial(
                    roughness: config.clockMaterial.roughness,
                    metallic: config.clockMaterial.metallic,
                    handRoughness: config.handMaterial.roughness,
                    handMetallic: config.handMaterial.metallic
                )
                

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
        wallMaterial.color = .init(tint: .white, texture: nil)
        wallMaterial.roughness = .init(floatLiteral: 0.9)
        wallMaterial.metallic = .init(floatLiteral: 0.0)
        wall = ModelEntity(mesh: wallMesh, materials: [wallMaterial])
        // Position wall behind the clocks (negative z) and rotate to face camera
        wall.position = [0, 0, -1.5]
        wall.transform.rotation = simd_quatf(angle: 0, axis: [0, 1, 0])
        anchor.addChild(wall)

        // Add frame boxes around the clock grid to create margins
        let frameThickness: Float = 1
        let frameDepth: Float = 0.5
        let frameMargin: Float = 1.5  // Distance from edge clocks to frame

        // Frame material - slightly glossy white (roughness 0.2 for subtle reflections)
        var frameMaterial = SimpleMaterial()
        frameMaterial.color = .init(tint: .white, texture: nil)
        frameMaterial.roughness = .init(floatLiteral: 1)
        frameMaterial.metallic = .init(floatLiteral: 0.0)

        // Top frame
        let topFrameMesh = MeshResource.generateBox(width: Float(ClockGridView.columns) * clockSpacing, height: frameThickness, depth: frameDepth)
        let topFrame = ModelEntity(mesh: topFrameMesh, materials: [frameMaterial])
        topFrame.position = [0, clockSpacing * Float(ClockGridView.rows) / 2 + frameThickness / 2, 0.75]
        anchor.addChild(topFrame)
        frameEntities.append(topFrame)

        // Bottom frame
        let bottomFrame = ModelEntity(mesh: topFrameMesh, materials: [frameMaterial])
        bottomFrame.position = [0, -clockSpacing * Float(ClockGridView.rows) / 2 - frameThickness / 2, 0.75]
        anchor.addChild(bottomFrame)
        frameEntities.append(bottomFrame)

        // Left frame
        let sideFrameMesh = MeshResource.generateBox(width: frameThickness, height: Float(ClockGridView.rows) * clockSpacing + (frameThickness * 2), depth: frameDepth)
        let leftFrame = ModelEntity(mesh: sideFrameMesh, materials: [frameMaterial])
        leftFrame.position = [-clockSpacing * Float(ClockGridView.columns) / 2 - frameThickness / 2, 0, 0.75]
        anchor.addChild(leftFrame)
        frameEntities.append(leftFrame)

        // Right frame
        let rightFrame = ModelEntity(mesh: sideFrameMesh, materials: [frameMaterial])
        rightFrame.position = [clockSpacing * Float(ClockGridView.columns) / 2 + frameThickness / 2, 0, 0.75]
        anchor.addChild(rightFrame)
        frameEntities.append(rightFrame)

        // 1. Main Key Light (DirectionalLight - disabled by default, SpotLight is used instead)
        keyLight = DirectionalLight()
        keyLight.light.intensity = config.keyLight.intensity
        keyLight.light.color = .init(red: 1.0, green: 0.98, blue: 0.95, alpha: 1.0)
        setKeyLightPosition(
            x: config.keyLight.x, y: config.keyLight.y, z: config.keyLight.z,
            rotX: config.keyLight.rotX, rotY: config.keyLight.rotY, rotZ: config.keyLight.rotZ
        )
        keyLight.shadow = DirectionalLightComponent.Shadow(
            maximumDistance: config.shadow.maxDistance,
            depthBias: config.shadow.depthBias
        )
        keyLight.isEnabled = false
        anchor.addChild(keyLight)

        // 2. Key SpotLight - ray-traced shadows (smoother quality)
        keySpotLight = SpotLight()
        keySpotLight.light.intensity = config.keySpotLight.position.intensity
        keySpotLight.light.color = .init(red: 1.0, green: 0.98, blue: 0.95, alpha: 1.0)
        keySpotLight.light.innerAngleInDegrees = config.keySpotLight.innerAngle
        keySpotLight.light.outerAngleInDegrees = config.keySpotLight.outerAngle
        keySpotLight.light.attenuationRadius = 50
        setKeySpotLightPosition(
            x: config.keySpotLight.position.x, y: config.keySpotLight.position.y, z: config.keySpotLight.position.z,
            rotX: config.keySpotLight.position.rotX, rotY: config.keySpotLight.position.rotY, rotZ: config.keySpotLight.position.rotZ
        )
        keySpotLight.shadow = SpotLightComponent.Shadow()
        keySpotLight.isEnabled = true
        anchor.addChild(keySpotLight)

        // 3. Fill Light - Frontal, provides general illumination
        fillLight = DirectionalLight()
        fillLight.light.intensity = config.fillLight.intensity
        fillLight.light.color = .init(red: 0.95, green: 0.98, blue: 1.0, alpha: 1.0)
        setFillLightPosition(
            x: config.fillLight.x, y: config.fillLight.y, z: config.fillLight.z,
            rotX: config.fillLight.rotX, rotY: config.fillLight.rotY, rotZ: config.fillLight.rotZ
        )
        anchor.addChild(fillLight)

        // 4. Rim/Edge Light - Back-left, subtle definition
        rimLight = DirectionalLight()
        rimLight.light.intensity = config.rimLight.intensity
        rimLight.light.color = .init(white: 1.0, alpha: 1.0)
        setRimLightPosition(
            x: config.rimLight.x, y: config.rimLight.y, z: config.rimLight.z,
            rotX: config.rimLight.rotX, rotY: config.rimLight.rotY, rotZ: config.rimLight.rotZ
        )
        anchor.addChild(rimLight)

        // Position camera to view entire grid
        setupCamera()

        // Try to completely disable IBL by creating a black environment
        do {
            // Create a small black image for environment lighting
            let size = 64
            var blackPixels = [UInt8](repeating: 0, count: size * size * 4)
            let data = Data(blackPixels)

            if let provider = CGDataProvider(data: data as CFData),
               let cgImage = CGImage(
                   width: size,
                   height: size,
                   bitsPerComponent: 8,
                   bitsPerPixel: 32,
                   bytesPerRow: size * 4,
                   space: CGColorSpaceCreateDeviceRGB(),
                   bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                   provider: provider,
                   decode: nil,
                   shouldInterpolate: false,
                   intent: .defaultIntent
               ) {
                let blackEnv = try EnvironmentResource(equirectangular: cgImage)
                arView.environment.lighting.resource = blackEnv
            }
        } catch {
            print("Failed to create black environment: \(error)")
        }
        arView.environment.lighting.intensityExponent = 0.0

        // Setup control panel for adjusting lighting (only in Preview mode)
        if showControls {
//            setupControlPanel()
        }
    }

    // MARK: - Control Panel (Floating Window)

    private var controlsContainerView: NSView?

    private var controlContentView: NSView? {
        return controlsContainerView
    }

    private func setupControlPanel() {
        let panelWidth: CGFloat = 280
        let panelHeight: CGFloat = 700  // Initial window height
        let contentHeight: CGFloat = 920  // Total content height

        // Create floating window
        let windowRect = NSRect(x: 100, y: 100, width: panelWidth, height: panelHeight)
        controlWindow = NSWindow(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        controlWindow?.title = "Lighting Controls"
        controlWindow?.isReleasedWhenClosed = false
        controlWindow?.level = .floating
        controlWindow?.backgroundColor = NSColor.windowBackgroundColor
        controlWindow?.minSize = NSSize(width: panelWidth, height: 300)

        // Create scroll view to fill the window
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizingMask = [.width, .height]
        scrollView.drawsBackground = false

        // Create a flipped container view so content starts from top
        let containerView = FlippedView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: contentHeight))
        controlsContainerView = containerView
        scrollView.documentView = containerView

        controlWindow?.contentView = scrollView

        var yOffset: CGFloat = 10  // Start from top (flipped coordinates)

        // Key Light Section (bottom-right, creates gradient)
        yOffset = addSectionHeader("Key Light (gradient source)", at: yOffset)
        yOffset = addSlider("Intensity", min: 0, max: 200000, value: Double(config.keyLight.intensity), tag: 1, at: yOffset)
        yOffset = addSlider("Pos X", min: -15, max: 150, value: Double(config.keyLight.x), tag: 2, at: yOffset)
        yOffset = addSlider("Pos Y", min: -15, max: 155, value: Double(config.keyLight.y), tag: 3, at: yOffset)
        yOffset = addSlider("Pos Z", min: 1, max: 150, value: Double(config.keyLight.z), tag: 4, at: yOffset)
        yOffset = addSlider("Rot X", min: -180, max: 180, value: Double(config.keyLight.rotX), tag: 6, at: yOffset)
        yOffset = addSlider("Rot Y", min: -180, max: 180, value: Double(config.keyLight.rotY), tag: 7, at: yOffset)
        yOffset = addSlider("Rot Z", min: -180, max: 180, value: Double(config.keyLight.rotZ), tag: 8, at: yOffset)
        yOffset = addSlider("Shadow Bias", min: 0.1, max: 10.0, value: Double(config.shadow.depthBias), tag: 5, at: yOffset)
        yOffset = addSlider("Shadow Distance", min: 5, max: 30, value: Double(config.shadow.maxDistance), tag: 9, at: yOffset)
        // SpotLight controls
        yOffset = addSlider("Spot Intensity", min: 0, max: 10000000, value: Double(config.keySpotLight.position.intensity), tag: 52, at: yOffset)
        yOffset = addSlider("Spot Inner Angle", min: 20, max: 80, value: Double(config.keySpotLight.innerAngle), tag: 50, at: yOffset)
        yOffset = addSlider("Spot Outer Angle", min: 30, max: 120, value: Double(config.keySpotLight.outerAngle), tag: 51, at: yOffset)

        // SpotLight toggle for ray-traced shadows
        let spotLightCheckbox = NSButton(checkboxWithTitle: "Use SpotLight (ray-traced shadows)", target: self, action: #selector(toggleSpotLight(_:)))
        spotLightCheckbox.frame = NSRect(x: 10, y: yOffset, width: 260, height: 20)
        containerView.addSubview(spotLightCheckbox)
        yOffset += 28

        // Fill Light Section (frontal, soft)
        yOffset += 10
        yOffset = addSectionHeader("Fill Light (frontal)", at: yOffset)
        yOffset = addSlider("Intensity", min: 0, max: 2000, value: Double(config.fillLight.intensity), tag: 10, at: yOffset)
        yOffset = addSlider("Pos X", min: -15, max: 15, value: Double(config.fillLight.x), tag: 11, at: yOffset)
        yOffset = addSlider("Pos Y", min: -10, max: 15, value: Double(config.fillLight.y), tag: 12, at: yOffset)
        yOffset = addSlider("Pos Z", min: -15, max: 30, value: Double(config.fillLight.z), tag: 13, at: yOffset)
        yOffset = addSlider("Rot X", min: -180, max: 180, value: Double(config.fillLight.rotX), tag: 14, at: yOffset)
        yOffset = addSlider("Rot Y", min: -180, max: 180, value: Double(config.fillLight.rotY), tag: 15, at: yOffset)
        yOffset = addSlider("Rot Z", min: -180, max: 180, value: Double(config.fillLight.rotZ), tag: 16, at: yOffset)

        // Rim Light Section (back-left, subtle)
        yOffset += 10
        yOffset = addSectionHeader("Rim Light (back-left)", at: yOffset)
        yOffset = addSlider("Intensity", min: 0, max: 1000, value: Double(config.rimLight.intensity), tag: 40, at: yOffset)
        yOffset = addSlider("Pos X", min: -15, max: 15, value: Double(config.rimLight.x), tag: 41, at: yOffset)
        yOffset = addSlider("Pos Y", min: -10, max: 10, value: Double(config.rimLight.y), tag: 42, at: yOffset)
        yOffset = addSlider("Pos Z", min: -15, max: 15, value: Double(config.rimLight.z), tag: 43, at: yOffset)
        yOffset = addSlider("Rot X", min: -180, max: 180, value: Double(config.rimLight.rotX), tag: 44, at: yOffset)
        yOffset = addSlider("Rot Y", min: -180, max: 180, value: Double(config.rimLight.rotY), tag: 45, at: yOffset)
        yOffset = addSlider("Rot Z", min: -180, max: 180, value: Double(config.rimLight.rotZ), tag: 46, at: yOffset)

        // Material Section (applies to frames and clocks)
        yOffset += 10
        yOffset = addSectionHeader("Material (Frame + Clocks)", at: yOffset)
        yOffset = addSlider("Roughness", min: 0, max: 1, value: Double(config.clockMaterial.roughness), tag: 20, at: yOffset)
        yOffset = addSlider("Metallic", min: 0, max: 1, value: Double(config.clockMaterial.metallic), tag: 21, at: yOffset)
        yOffset = addSlider("Hand Roughness", min: 0, max: 1, value: Double(config.handMaterial.roughness), tag: 22, at: yOffset)
        yOffset = addSlider("Hand Metallic", min: 0, max: 1, value: Double(config.handMaterial.metallic), tag: 23, at: yOffset)

        // Environment
        yOffset += 10
        yOffset = addSectionHeader("Environment", at: yOffset)
        yOffset = addSlider("Ambient", min: 0, max: 2, value: Double(config.ambient), tag: 30, at: yOffset)

        // Camera Section
        yOffset += 10
        yOffset = addSectionHeader("Camera", at: yOffset)
        // Camera Z is calculated based on grid size, but can be overridden
        let defaultCameraZ = max(Float(ClockGridView.columns), Float(ClockGridView.rows)) * clockSpacing * 0.9
        yOffset = addSlider("Pos X", min: -20, max: 20, value: Double(config.camera.x), tag: 60, at: yOffset)
        yOffset = addSlider("Pos Y", min: -20, max: 20, value: Double(config.camera.y), tag: 61, at: yOffset)
        yOffset = addSlider("Pos Z", min: 5, max: 50, value: Double(config.camera.z != 0 ? config.camera.z : defaultCameraZ), tag: 62, at: yOffset)
        yOffset = addSlider("Rot X", min: -180, max: 180, value: Double(config.camera.rotX), tag: 63, at: yOffset)
        yOffset = addSlider("Rot Y", min: -180, max: 180, value: Double(config.camera.rotY), tag: 64, at: yOffset)
        yOffset = addSlider("Rot Z", min: -180, max: 180, value: Double(config.camera.rotZ), tag: 65, at: yOffset)
        yOffset = addSlider("FOV", min: 10, max: 120, value: Double(config.camera.fov), tag: 66, at: yOffset)

        // Print button
        yOffset += 10
        let printButton = NSButton(frame: NSRect(x: 10, y: yOffset, width: panelWidth - 40, height: 24))
        printButton.title = "Print Current Values"
        printButton.bezelStyle = .rounded
        printButton.target = self
        printButton.action = #selector(printCurrentValues)
        containerView.addSubview(printButton)
        yOffset += 34

        // Resize container to fit content
        containerView.frame = NSRect(x: 0, y: 0, width: panelWidth, height: yOffset + 10)

        // Show the floating window
        controlWindow?.orderFront(nil)
    }

    private func createLabel(_ text: String, bold: Bool = false) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.textColor = .labelColor
        label.font = bold ? NSFont.boldSystemFont(ofSize: 12) : NSFont.systemFont(ofSize: 10)
        return label
    }

    private func addSectionHeader(_ text: String, at y: CGFloat) -> CGFloat {
        guard let contentView = controlContentView else { return y }
        let label = createLabel(text, bold: true)
        label.frame = NSRect(x: 10, y: y, width: 260, height: 16)
        contentView.addSubview(label)
        return y + 20  // Flipped: y increases downward
    }

    private func addSlider(_ name: String, min: Double, max: Double, value: Double, tag: Int, at y: CGFloat) -> CGFloat {
        guard let contentView = controlContentView else { return y }
        let label = createLabel("\(name): \(String(format: "%.2f", value))")
        label.frame = NSRect(x: 10, y: y, width: 260, height: 14)
        label.tag = tag + 1000  // Use offset for label tags
        contentView.addSubview(label)

        let slider = NSSlider(value: value, minValue: min, maxValue: max, target: self, action: #selector(sliderChanged(_:)))
        slider.frame = NSRect(x: 10, y: y + 14, width: 260, height: 20)  // Flipped: slider below label
        slider.tag = tag
        contentView.addSubview(slider)

        return y + 38  // Flipped: y increases downward
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        let value = sender.floatValue

        // Update label
        if let label = controlContentView?.viewWithTag(sender.tag + 1000) as? NSTextField {
            let name = label.stringValue.components(separatedBy: ":").first ?? ""
            label.stringValue = "\(name): \(String(format: "%.2f", value))"
        }

        switch sender.tag {
        // Key Light (controls both DirectionalLight and SpotLight)
        case 1:
            keyLight.light.intensity = value
        case 2, 3, 4, 6, 7, 8: updateKeyLightPosition()
        case 5, 9:
            updateShadowSettings()

        // Fill Light
        case 10: fillLight.light.intensity = value
        case 11, 12, 13, 14, 15, 16: updateFillLightPosition()

        // Rim Light
        case 40: rimLight.light.intensity = value
        case 41, 42, 43, 44, 45, 46: updateRimLightPosition()

        // SpotLight controls
        case 50: keySpotLight.light.innerAngleInDegrees = value
        case 51: keySpotLight.light.outerAngleInDegrees = value
        case 52: keySpotLight.light.intensity = value

        // Frame Material
        case 20, 21, 22, 23: updateFrameMaterial()

        // Environment
        case 30: arView.environment.lighting.intensityExponent = value

        // Camera
        case 60, 61, 62, 63, 64, 65: updateCameraPosition()
        case 66: camera.camera.fieldOfViewInDegrees = value

        default: break
        }
    }

    @objc private func toggleSpotLight(_ sender: NSButton) {
        useSpotLight = sender.state == .on
        keyLight.isEnabled = !useSpotLight
        keySpotLight.isEnabled = useSpotLight
    }

    private func updateShadowSettings() {
        guard let contentView = controlContentView,
              let biasSlider = contentView.viewWithTag(5) as? NSSlider,
              let distanceSlider = contentView.viewWithTag(9) as? NSSlider else { return }

        keyLight.shadow = DirectionalLightComponent.Shadow(
            maximumDistance: distanceSlider.floatValue,
            depthBias: biasSlider.floatValue
        )
    }

    private func updateKeyLightPosition() {
        guard let contentView = controlContentView,
              let xSlider = contentView.viewWithTag(2) as? NSSlider,
              let ySlider = contentView.viewWithTag(3) as? NSSlider,
              let zSlider = contentView.viewWithTag(4) as? NSSlider,
              let rotXSlider = contentView.viewWithTag(6) as? NSSlider,
              let rotYSlider = contentView.viewWithTag(7) as? NSSlider,
              let rotZSlider = contentView.viewWithTag(8) as? NSSlider else { return }

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

        // Also update SpotLight position and rotation
        setKeySpotLightPosition(x: pos.x, y: pos.y, z: pos.z, rotX: rotXSlider.floatValue, rotY: rotYSlider.floatValue, rotZ: rotZSlider.floatValue)
    }

    private func setKeyLightPosition(x: Float, y: Float, z: Float, rotX: Float, rotY: Float, rotZ: Float) {
        let pos: SIMD3<Float> = [x, y, z]
        keyLight.look(at: [0, 0, 0], from: pos, relativeTo: nil)

        let rotXRad = rotX * .pi / 180.0
        let rotYRad = rotY * .pi / 180.0
        let rotZRad = rotZ * .pi / 180.0
        let additionalRotation = simd_quatf(angle: rotXRad, axis: [1, 0, 0]) *
                                  simd_quatf(angle: rotYRad, axis: [0, 1, 0]) *
                                  simd_quatf(angle: rotZRad, axis: [0, 0, 1])
        keyLight.transform.rotation = keyLight.transform.rotation * additionalRotation
    }

    private func setKeySpotLightPosition(x: Float, y: Float, z: Float, rotX: Float, rotY: Float, rotZ: Float) {
        let spotPos: SIMD3<Float> = [x, y, z]

        // Set position first
        keySpotLight.position = spotPos

        // Calculate direction to look at center
        let direction = normalize(SIMD3<Float>(0, 0, 0) - spotPos)

        // Create rotation to face the target
        let up = SIMD3<Float>(0, 1, 0)
        let right = normalize(cross(up, -direction))
        let adjustedUp = cross(-direction, right)

        // Build rotation matrix and convert to quaternion
        let rotationMatrix = simd_float3x3(columns: (right, adjustedUp, -direction))
        var baseRotation = simd_quatf(rotationMatrix)

        // Apply additional rotation offsets (convert degrees to radians)
        let rotXRad = rotX * .pi / 180.0
        let rotYRad = rotY * .pi / 180.0
        let rotZRad = rotZ * .pi / 180.0
        let additionalRotation = simd_quatf(angle: rotXRad, axis: [1, 0, 0]) *
                                  simd_quatf(angle: rotYRad, axis: [0, 1, 0]) *
                                  simd_quatf(angle: rotZRad, axis: [0, 0, 1])
        keySpotLight.transform.rotation = baseRotation * additionalRotation
    }

    private func updateFillLightPosition() {
        guard let contentView = controlContentView,
              let xSlider = contentView.viewWithTag(11) as? NSSlider,
              let ySlider = contentView.viewWithTag(12) as? NSSlider,
              let zSlider = contentView.viewWithTag(13) as? NSSlider,
              let rotXSlider = contentView.viewWithTag(14) as? NSSlider,
              let rotYSlider = contentView.viewWithTag(15) as? NSSlider,
              let rotZSlider = contentView.viewWithTag(16) as? NSSlider else { return }

        setFillLightPosition(x: xSlider.floatValue, y: ySlider.floatValue, z: zSlider.floatValue, rotX: rotXSlider.floatValue, rotY: rotYSlider.floatValue, rotZ: rotZSlider.floatValue)
    }

    private func setFillLightPosition(x: Float, y: Float, z: Float, rotX: Float, rotY: Float, rotZ: Float) {
        let pos: SIMD3<Float> = [x, y, z]
        fillLight.look(at: [0, 0, 0], from: pos, relativeTo: nil)

        let additionalRotation = simd_quatf(angle: rotX, axis: [1, 0, 0]) *
                                  simd_quatf(angle: rotY, axis: [0, 1, 0]) *
                                  simd_quatf(angle: rotZ, axis: [0, 0, 1])
        fillLight.transform.rotation = fillLight.transform.rotation * additionalRotation
    }

    private func updateRimLightPosition() {
        guard let contentView = controlContentView,
              let xSlider = contentView.viewWithTag(41) as? NSSlider,
              let ySlider = contentView.viewWithTag(42) as? NSSlider,
              let zSlider = contentView.viewWithTag(43) as? NSSlider,
              let rotXSlider = contentView.viewWithTag(44) as? NSSlider,
              let rotYSlider = contentView.viewWithTag(45) as? NSSlider,
              let rotZSlider = contentView.viewWithTag(46) as? NSSlider else { return }

        setRimLightPosition(x: xSlider.floatValue, y: ySlider.floatValue, z: zSlider.floatValue, rotX: rotXSlider.floatValue, rotY: rotYSlider.floatValue, rotZ: rotZSlider.floatValue)
    }

    private func setRimLightPosition(x: Float, y: Float, z: Float, rotX: Float, rotY: Float, rotZ: Float) {
        let pos: SIMD3<Float> = [x, y, z]
        rimLight.look(at: [0, 0, 0], from: pos, relativeTo: nil)

        let additionalRotation = simd_quatf(angle: rotX, axis: [1, 0, 0]) *
                                  simd_quatf(angle: rotY, axis: [0, 1, 0]) *
                                  simd_quatf(angle: rotZ, axis: [0, 0, 1])
        rimLight.transform.rotation = rimLight.transform.rotation * additionalRotation
    }

    private func updateCameraPosition() {
        guard let contentView = controlContentView,
              let xSlider = contentView.viewWithTag(60) as? NSSlider,
              let ySlider = contentView.viewWithTag(61) as? NSSlider,
              let zSlider = contentView.viewWithTag(62) as? NSSlider,
              let rotXSlider = contentView.viewWithTag(63) as? NSSlider,
              let rotYSlider = contentView.viewWithTag(64) as? NSSlider,
              let rotZSlider = contentView.viewWithTag(65) as? NSSlider else { return }

        setCameraPosition(x: xSlider.floatValue, y: ySlider.floatValue, z: zSlider.floatValue, rotX: rotXSlider.floatValue, rotY: rotYSlider.floatValue, rotZ: rotZSlider.floatValue)
    }

    private func setCameraPosition(x: Float, y: Float, z: Float, rotX: Float, rotY: Float, rotZ: Float) {
        let pos: SIMD3<Float> = [x, y, z]
        camera.look(at: [0, 0, 0], from: pos, relativeTo: nil)

        let additionalRotation = simd_quatf(angle: rotX, axis: [1, 0, 0]) *
                                  simd_quatf(angle: rotY, axis: [0, 1, 0]) *
                                  simd_quatf(angle: rotZ, axis: [0, 0, 1])
        camera.transform.rotation = camera.transform.rotation * additionalRotation
    }

    private func updateFrameMaterial() {
        guard let contentView = controlContentView,
              let roughnessSlider = contentView.viewWithTag(20) as? NSSlider,
              let metallicSlider = contentView.viewWithTag(21) as? NSSlider,
              let handRoughnessSlider = contentView.viewWithTag(22) as? NSSlider,
              let handMetallicSlider = contentView.viewWithTag(23) as? NSSlider else { return }

        let roughness = roughnessSlider.floatValue
        let metallic = metallicSlider.floatValue
        let handRoughness = handRoughnessSlider.floatValue
        let handMetallic = handMetallicSlider.floatValue

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
                clock.updateMaterial(roughness: roughness, metallic: metallic, handRoughness: handRoughness, handMetallic: handMetallic)
            }
        }
    }

    @objc private func printCurrentValues() {
        guard let cv = controlContentView else { return }
        print("\n// === CURRENT LIGHTING VALUES ===")
        print("keyLight.light.intensity = \((cv.viewWithTag(1) as? NSSlider)?.floatValue ?? 0)")
        print("keyLight position: [\((cv.viewWithTag(2) as? NSSlider)?.floatValue ?? 0), \((cv.viewWithTag(3) as? NSSlider)?.floatValue ?? 0), \((cv.viewWithTag(4) as? NSSlider)?.floatValue ?? 0)]")
        print("keyLight rotation (deg): [\((cv.viewWithTag(6) as? NSSlider)?.floatValue ?? 0), \((cv.viewWithTag(7) as? NSSlider)?.floatValue ?? 0), \((cv.viewWithTag(8) as? NSSlider)?.floatValue ?? 0)]")
        print("keyLight shadow depthBias: \((cv.viewWithTag(5) as? NSSlider)?.floatValue ?? 0)")
        print("keyLight shadow maxDistance: \((cv.viewWithTag(9) as? NSSlider)?.floatValue ?? 0)")
        print("keySpotLight.light.intensity = \((cv.viewWithTag(52) as? NSSlider)?.floatValue ?? 0)")
        print("keySpotLight.light.innerAngleInDegrees = \((cv.viewWithTag(50) as? NSSlider)?.floatValue ?? 0)")
        print("keySpotLight.light.outerAngleInDegrees = \((cv.viewWithTag(51) as? NSSlider)?.floatValue ?? 0)")
        print("fillLight.light.intensity = \((cv.viewWithTag(10) as? NSSlider)?.floatValue ?? 0)")
        print("fillLight position: [\((cv.viewWithTag(11) as? NSSlider)?.floatValue ?? 0), \((cv.viewWithTag(12) as? NSSlider)?.floatValue ?? 0), \((cv.viewWithTag(13) as? NSSlider)?.floatValue ?? 0)]")
        print("fillLight rotation (deg): [\((cv.viewWithTag(14) as? NSSlider)?.floatValue ?? 0), \((cv.viewWithTag(15) as? NSSlider)?.floatValue ?? 0), \((cv.viewWithTag(16) as? NSSlider)?.floatValue ?? 0)]")
        print("rimLight.light.intensity = \((cv.viewWithTag(40) as? NSSlider)?.floatValue ?? 0)")
        print("rimLight position: [\((cv.viewWithTag(41) as? NSSlider)?.floatValue ?? 0), \((cv.viewWithTag(42) as? NSSlider)?.floatValue ?? 0), \((cv.viewWithTag(43) as? NSSlider)?.floatValue ?? 0)]")
        print("rimLight rotation (deg): [\((cv.viewWithTag(44) as? NSSlider)?.floatValue ?? 0), \((cv.viewWithTag(45) as? NSSlider)?.floatValue ?? 0), \((cv.viewWithTag(46) as? NSSlider)?.floatValue ?? 0)]")
        print("clockMaterial.roughness = \((cv.viewWithTag(20) as? NSSlider)?.floatValue ?? 0)")
        print("clockMaterial.metallic = \((cv.viewWithTag(21) as? NSSlider)?.floatValue ?? 0)")
        print("handMaterial.roughness = \((cv.viewWithTag(22) as? NSSlider)?.floatValue ?? 0)")
        print("handMaterial.metallic = \((cv.viewWithTag(23) as? NSSlider)?.floatValue ?? 0)")
        print("environment.lighting.intensityExponent = \((cv.viewWithTag(30) as? NSSlider)?.floatValue ?? 0)")
        print("camera position: [\((cv.viewWithTag(60) as? NSSlider)?.floatValue ?? 0), \((cv.viewWithTag(61) as? NSSlider)?.floatValue ?? 0), \((cv.viewWithTag(62) as? NSSlider)?.floatValue ?? 0)]")
        print("camera rotation (deg): [\((cv.viewWithTag(63) as? NSSlider)?.floatValue ?? 0), \((cv.viewWithTag(64) as? NSSlider)?.floatValue ?? 0), \((cv.viewWithTag(65) as? NSSlider)?.floatValue ?? 0)]")
        print("camera.fieldOfViewInDegrees = \((cv.viewWithTag(66) as? NSSlider)?.floatValue ?? 0)")
        print("// ================================\n")
    }

    private func loadModelTemplate() -> ModelEntity? {
        // Use Bundle(for:) to get the screensaver's bundle, not Bundle.main
        // Bundle.main points to the host app (System Settings) when running as screensaver
        let bundle = Bundle(for: ClockGridView.self)
        guard let url = bundle.url(forResource: "box_with_cutout_15", withExtension: "usdz") else {
            print("USDZ file not found in bundle: \(bundle.bundlePath)")
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
        camera = PerspectiveCamera()
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
