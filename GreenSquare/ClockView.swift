//
//  ClockView.swift
//  GreenSquare
//
//  Created by Robert Tolar Haining on 4/9/20.
//  Copyright © 2020 Robert Tolar Haining. All rights reserved.
//

import AppKit
import RealityKit
import ModelIO

class ClockView: NSView {
    private var arView: ARView!
    private var sphereEntity: ModelEntity!
    private var pivotMinuteHand: Entity?
    private var pivotHourHand: Entity?

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
        arView.environment.background = .color(.white)
        addSubview(arView)

        // Create anchor for our scene
        let anchor = AnchorEntity(world: .zero)
        arView.scene.addAnchor(anchor)

        // Load USDZ model
        if let modelEntity = try? loadModelFromUSDZ(named: "box_with_cutout_3") {
            sphereEntity = modelEntity
            sphereEntity.position = [0, 0, -0.5]
            sphereEntity.name = "MainModel"

            // Optional: Override materials
            var material = SimpleMaterial()
            material.color = .init(tint: .white, texture: nil)
            material.roughness = .init(floatLiteral: 0.3)
            material.metallic = .init(floatLiteral: 0.5)
            
            sphereEntity.transform.rotation = simd_quatf(angle: 1.572 * 4, axis: [0, 1, 0])
            
            sphereEntity.model?.materials = [material]

            anchor.addChild(sphereEntity)

            // Since the USDZ is a single mesh, add separate child objects you can manipulate
            // Create a pivot point entity (invisible, just for rotation)
            pivotMinuteHand = Entity()
            pivotMinuteHand!.name = "PivotMinuteHand"
            pivotMinuteHand!.position = [0, 0, 0.5] // This is where the pivot point will be
            sphereEntity.addChild(pivotMinuteHand!)

            // Create the movable box
            let minuteHandHeight = Float(0.8);
            let minuteHand = MeshResource.generateBox(width: 0.2, height: minuteHandHeight, depth: 0.02)
            var minuteHandMeterial = SimpleMaterial()
            minuteHandMeterial.color = .init(tint: .black, texture: nil)
            minuteHandMeterial.metallic = .init(floatLiteral: 0.8)

            let movableMinuteHand = ModelEntity(mesh: minuteHand, materials: [minuteHandMeterial])
            movableMinuteHand.name = "MovableSphere"
            movableMinuteHand.position = [0, minuteHandHeight / 2, 0]

            pivotMinuteHand!.addChild(movableMinuteHand)


            pivotHourHand = Entity()
            pivotHourHand!.name = "PivotHourHand"
            pivotHourHand!.position = [0, 0, 0.5]
            sphereEntity.addChild(pivotHourHand!)
            
            // Create the movable box
            let hourHandHeight = Float(0.7);
            let hourHand = MeshResource.generateBox(width: 0.2, height: hourHandHeight, depth: 0.02)
            var hourHandMaterial = SimpleMaterial()
            hourHandMaterial.color = .init(tint: .black, texture: nil)
            hourHandMaterial.metallic = .init(floatLiteral: 0.8)

            let movableHourHand = ModelEntity(mesh: hourHand, materials: [hourHandMaterial])
            movableHourHand.name = "MovableHourHand"
            movableHourHand.position = [0, hourHandHeight / 2, 0]

            pivotHourHand!.addChild(movableHourHand)

            // Print all entity names in the model hierarchy
            printEntityHierarchy(sphereEntity)
        } else {
            // Fallback: create a simple box if USDZ not found
            let boxMesh = MeshResource.generateBox(size: [0.3, 0.2, 0.1])
            var material = SimpleMaterial()
            material.color = .init(tint: .white, texture: nil)
            sphereEntity = ModelEntity(mesh: boxMesh, materials: [material])
            sphereEntity.position = [0, 0, -0.5]
            anchor.addChild(sphereEntity)
        }

        // Add fill light
        let fillLight = PointLight()
        fillLight.light.intensity = 2000
        fillLight.light.color = .white
        fillLight.position = [-0.2, -0.1, 0.2]
        anchor.addChild(fillLight)
    }

    private func loadModelFromUSDZ(named name: String) throws -> ModelEntity? {
        // Try to find the USDZ file in the bundle
        guard let url = Bundle.main.url(forResource: name, withExtension: "usdz") else {
            print("USDZ file '\(name).usdz' not found in bundle")
            return nil
        }

        // Load the model entity from the USDZ file
        let modelEntity = try ModelEntity.loadModel(contentsOf: url)
        return modelEntity
    }

    private func printEntityHierarchy(_ entity: Entity, indent: String = "") {
        print("\(indent)Entity: '\(entity.name)'")
        print("\(indent)  Type: \(type(of: entity))")
        print("\(indent)  Children count: \(entity.children.count)")

        if let modelEntity = entity as? ModelEntity {
            print("\(indent)  Has model component: \(modelEntity.model != nil)")
            if let model = modelEntity.model {
                print("\(indent)  Mesh: \(model.mesh)")
                print("\(indent)  Materials count: \(model.materials.count)")
            }
        }

        print("\(indent)  Components: \(entity.components)")
        print("\(indent)  Position: \(entity.position)")
        print("\(indent)---")

        for child in entity.children {
            printEntityHierarchy(child, indent: indent + "  ")
        }
    }

    // Helper function to move a specific object in the model
    func moveObject(named objectName: String, to position: SIMD3<Float>) {
        if let object = sphereEntity.findEntity(named: objectName) {
            object.position = position
        }
    }

    // Helper function to rotate a specific object
    func rotateObject(named objectName: String, byDegrees degrees: Float, axis: SIMD3<Float>) {
        if let object = sphereEntity.findEntity(named: objectName) {
            let radians = degrees * .pi / 180.0
            let rotation = simd_quatf(angle: radians, axis: axis)
            object.transform.rotation = rotation * object.transform.rotation
        }
    }

    // Helper function to scale a specific object
    func scaleObject(named objectName: String, scale: SIMD3<Float>) {
        if let object = sphereEntity.findEntity(named: objectName) {
            object.scale = scale
        }
    }
    
    /// Sets the clock hands to absolute angles (in degrees, 0 = 12 o'clock, clockwise)
    func setClockHands(minuteHandDeg: Float, hourHandDeg: Float) {
        let minuteRadians = -minuteHandDeg * .pi / 180.0
        let hourRadians = -hourHandDeg * .pi / 180.0

        pivotMinuteHand?.transform.rotation = simd_quatf(angle: minuteRadians, axis: [0, 0, 1])
        pivotHourHand?.transform.rotation = simd_quatf(angle: hourRadians, axis: [0, 0, 1])
    }
}
