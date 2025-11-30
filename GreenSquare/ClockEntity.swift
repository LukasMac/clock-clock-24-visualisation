//
//  ClockEntity.swift
//  GreenSquare
//

import RealityKit

/// Represents a single clock (cylinder + two hands) as an Entity in a shared scene
class ClockEntity: Entity {
    private var clockModel: ModelEntity?
    private var pivotMinuteHand: Entity?
    private var pivotHourHand: Entity?

    required init() {
        super.init()
    }

    init(modelTemplate: ModelEntity?) {
        super.init()
        setupClock(modelTemplate: modelTemplate)
    }

    private func setupClock(modelTemplate: ModelEntity?) {
        // Clone the model template or create fallback
        if let template = modelTemplate {
            clockModel = template.clone(recursive: true)
        } else {
            // Fallback: create a simple box
            let boxMesh = MeshResource.generateBox(size: [0.3, 0.2, 0.1])
            var material = SimpleMaterial()
            material.color = .init(tint: .white, texture: nil)
            clockModel = ModelEntity(mesh: boxMesh, materials: [material])
        }

        guard let clockModel = clockModel else { return }

        // Apply material - slightly glossy white (roughness 0.2 for subtle reflections)
        var material = SimpleMaterial()
        material.color = .init(tint: .white, texture: nil)
        material.roughness = .init(floatLiteral: 0.2)
        material.metallic = .init(floatLiteral: 0.0)
        clockModel.model?.materials = [material]

        // Base rotation for the model
        clockModel.transform.rotation = simd_quatf(angle: 1.5708 * 4, axis: [0, 1, 0])

        addChild(clockModel)

        let handHeight: Float = 0.02
        let handWidth: Float = 0.2
        let hourHandZPosition: Float = 0.94

        // Create minute hand pivot
        pivotMinuteHand = Entity()
        pivotMinuteHand!.name = "PivotMinuteHand"
        pivotMinuteHand!.position = [0, 0, 0]
        clockModel.addChild(pivotMinuteHand!)

        // Create minute hand
        let minuteHandHeight: Float = 0.9
        let minuteHandMesh = MeshResource.generateBox(width: handWidth, height: minuteHandHeight, depth: handHeight)
        var minuteHandMaterial = SimpleMaterial()
        minuteHandMaterial.color = .init(tint: .black, texture: nil)
        minuteHandMaterial.metallic = .init(floatLiteral: 0.8)

        let minuteHand = ModelEntity(mesh: minuteHandMesh, materials: [minuteHandMaterial])
        minuteHand.position = [0, minuteHandHeight / 2, hourHandZPosition + handHeight]
        pivotMinuteHand!.addChild(minuteHand)

        // Create hour hand pivot
        pivotHourHand = Entity()
        pivotHourHand!.name = "PivotHourHand"
        pivotHourHand!.position = [0, 0, 0]
        clockModel.addChild(pivotHourHand!)

        // Create hour hand
        let hourHandHeight: Float = 0.8
        let hourHandMesh = MeshResource.generateBox(width: handWidth, height: hourHandHeight, depth: handHeight)
        var hourHandMaterial = SimpleMaterial()
        hourHandMaterial.color = .init(tint: .black, texture: nil)
        hourHandMaterial.metallic = .init(floatLiteral: 0.8)

        let hourHand = ModelEntity(mesh: hourHandMesh, materials: [hourHandMaterial])
        hourHand.position = [0, hourHandHeight / 2, hourHandZPosition]
        pivotHourHand!.addChild(hourHand)

        // Create center cylinder
        let centerCylinderHeight: Float =  handHeight * 2 + 0.01
        let centerCylinderMesh = MeshResource.generateCylinder(height: centerCylinderHeight, radius: handWidth / 2)
        var centerCylinderMaterial = SimpleMaterial()
        centerCylinderMaterial.color = .init(tint: .black, texture: nil)
        centerCylinderMaterial.metallic = .init(floatLiteral: 0.8)

        let centerCylinder = ModelEntity(mesh: centerCylinderMesh, materials: [centerCylinderMaterial])
        centerCylinder.position = [0, 0, hourHandZPosition]
        // Rotate the cylinder 90 degrees around the X axis
        centerCylinder.transform.rotation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        clockModel.addChild(centerCylinder)
    }

    /// Sets the clock hands to absolute angles (in degrees, 0 = 12 o'clock, clockwise)
    func setClockHands(minuteHandDeg: Float, hourHandDeg: Float) {
        let minuteRadians = -minuteHandDeg * .pi / 180.0
        let hourRadians = -hourHandDeg * .pi / 180.0

        pivotMinuteHand?.transform.rotation = simd_quatf(angle: minuteRadians, axis: [0, 0, 1])
        pivotHourHand?.transform.rotation = simd_quatf(angle: hourRadians, axis: [0, 0, 1])
    }

    /// Updates the clock body material
    func updateMaterial(roughness: Float, metallic: Float) {
        var material = SimpleMaterial()
        material.color = .init(tint: .white, texture: nil)
        material.roughness = .init(floatLiteral: roughness)
        material.metallic = .init(floatLiteral: metallic)
        clockModel?.model?.materials = [material]
    }
}
