//
//  GreenSquareView.swift
//  GreenSquare
//
//  Created by Robert Tolar Haining on 4/9/20.
//  Copyright © 2020 Robert Tolar Haining. All rights reserved.
//

import AppKit
import RealityKit

class GreenSquareView: NSView {
    private var arView: ARView!
    private var sphereEntity: ModelEntity!
    private var currentRotation: Float = 0
    private var lightEntity: PointLight!

    init() {
        super.init(frame: .zero)
        setupScene()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupScene() {
        // Create RealityKit ARView (works without AR on macOS)
        arView = ARView(frame: bounds)
        arView.autoresizingMask = [.width, .height]
        arView.environment.background = .color(.black)
        addSubview(arView)

        // Create anchor for our scene
        let anchor = AnchorEntity(world: .zero)
        arView.scene.addAnchor(anchor)

        // Create sphere mesh
        let sphereMesh = MeshResource.generateSphere(radius: 0.15)

        // Create white material
        var material = SimpleMaterial()
        material.color = .init(tint: .white, texture: nil)
        material.roughness = .init(floatLiteral: 0.3)
        material.metallic = .init(floatLiteral: 0.5)

        // Create sphere entity
        sphereEntity = ModelEntity(mesh: sphereMesh, materials: [material])
        sphereEntity.position = [0, 0, -0.5]
        anchor.addChild(sphereEntity)

        // Add main point light
        let mainLight = PointLight()
        mainLight.light.intensity = 5000
        mainLight.light.color = .white
        mainLight.position = [0.3, 0.3, 0.3]
        anchor.addChild(mainLight)
        lightEntity = mainLight

        // Add fill light
        let fillLight = PointLight()
        fillLight.light.intensity = 2000
        fillLight.light.color = .white
        fillLight.position = [-0.2, -0.1, 0.2]
        anchor.addChild(fillLight)

        // Animate the main light
        animateLight()
    }

    private func animateLight() {
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let time = Date().timeIntervalSinceReferenceDate
            let x = Float(sin(time * 0.5)) * 0.3
            self.lightEntity.position.x = x
        }
    }

    func rotateSphere(byDegrees degrees: CGFloat) {
        let radians = Float(degrees * .pi / 180.0)
        currentRotation += radians
        sphereEntity.transform.rotation = simd_quatf(angle: currentRotation, axis: [0, 1, 0])
    }
}
