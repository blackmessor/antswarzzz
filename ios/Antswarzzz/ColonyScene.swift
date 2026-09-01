import SpriteKit
import SwiftUI

/// SpriteKit scene rendering the ant colony cross-section.
/// Organic cave-like rooms clipped from the generated images, mounted on a winding gallery.
final class ColonyScene: SKScene {

    // MARK: - Configuration

    private let tunnelWidth: CGFloat = 66
    private let roomSize = CGSize(width: 168, height: 112)
    private let verticalSpacing: CGFloat = 208
    private let galleryAmplitude: CGFloat = 30
    private let galleryWavelength: CGFloat = 400
    private let earthColor = SKColor(red: 0.17, green: 0.11, blue: 0.07, alpha: 1.0)   // #2B1B17
    private let tunnelColor = SKColor(red: 0.10, green: 0.06, blue: 0.03, alpha: 1.0)

    // MARK: - Data binding

    var buildings: [ColonyBuilding] = [] {
        didSet { updateRoomNodes() }
    }

    // MARK: - Node containers

    private var cameraNode: SKCameraNode!
    private var roomsContainer: SKNode?
    private var roomNodes: [Int: SKNode] = [:]
    private var didSetup = false

    // MARK: - Gallery geometry

    /// Horizontal offset of the gallery centre at a given height (sinusoidal wiggle).
    private func galleryX(atY y: CGFloat) -> CGFloat {
        galleryAmplitude * sin(y / galleryWavelength)
    }

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = earthColor
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        setupCamera()
        setupBackground()
        setupGallery()
        setupRoomSlots()
        didSetup = true
        updateRoomNodes()
    }

    // MARK: - Setup

    private func setupCamera() {
        cameraNode = SKCameraNode()
        camera = cameraNode
        addChild(cameraNode)
        cameraNode.position = .zero
        cameraNode.setScale(0.78)
    }

    private func setupBackground() {
        let texture = SKTexture(imageNamed: "BackgroundEmpty")
        let bg = SKSpriteNode(texture: texture)
        bg.size = CGSize(width: frame.width * 1.4, height: frame.height * 1.7)
        bg.zPosition = -20
        bg.position = CGPoint(x: 0, y: -80)
        addChild(bg)
    }

    /// Winding vertical gallery — a thick, sinuous stroke instead of a straight line.
    private func setupGallery() {
        let gallery = SKShapeNode()
        gallery.zPosition = -10
        gallery.strokeColor = tunnelColor
        gallery.lineWidth = tunnelWidth
        gallery.lineCap = .round
        gallery.lineJoin = .round

        let path = CGMutablePath()
        let startY: CGFloat = -1650
        let endY: CGFloat = 1650
        let step: CGFloat = 12
        var first = true
        var y = startY
        while y <= endY {
            let x = galleryX(atY: y)
            if first {
                path.move(to: CGPoint(x: x, y: y))
                first = false
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
            y += step
        }
        gallery.path = path
        addChild(gallery)

        // Organic texture lines along the tunnel walls
        let walls = SKShapeNode()
        walls.zPosition = -9
        walls.strokeColor = SKColor(red: 0.30, green: 0.18, blue: 0.10, alpha: 0.5)
        walls.lineWidth = 1.5
        walls.lineCap = .round
        let wallPath = CGMutablePath()
        y = startY
        while y <= endY {
            let x = galleryX(atY: y)
            wallPath.move(to: CGPoint(x: x - tunnelWidth / 2 - 4, y: y))
            wallPath.addLine(to: CGPoint(x: x - tunnelWidth / 2 + 4, y: y + 4))
            wallPath.move(to: CGPoint(x: x + tunnelWidth / 2 - 4, y: y))
            wallPath.addLine(to: CGPoint(x: x + tunnelWidth / 2 + 4, y: y + 4))
            y += 70
        }
        walls.path = wallPath
        addChild(walls)
    }

    // MARK: - Cave shapes

    /// Builds an irregular, cave-like blob path centred on origin, sized to roomSize.
    private func cavePath(size: CGSize, wobble: CGFloat = 10) -> CGPath {
        let path = CGMutablePath()
        let w = size.width / 2
        let h = size.height / 2
        let points = 12
        for i in 0..<points {
            let angle = CGFloat(i) / CGFloat(points) * 2 * .pi
            let radX = w * (1 + wobble / 100 * sin(angle * 3))
            let radY = h * (1 + wobble / 100 * cos(angle * 2.5))
            let px = cos(angle) * radX
            let py = sin(angle) * radY
            if i == 0 {
                path.move(to: CGPoint(x: px, y: py))
            } else {
                path.addLine(to: CGPoint(x: px, y: py))
            }
        }
        path.closeSubpath()
        return path
    }

    // MARK: - Slots

    private func setupRoomSlots() {
        let rContainer = SKNode()
        rContainer.zPosition = 0
        addChild(rContainer)
        roomsContainer = rContainer

        for i in 1...13 {
            let side: CGFloat = (i % 2 == 0) ? 1 : -1
            let y = 900 - CGFloat(i - 1) * verticalSpacing
            let gx = galleryX(atY: y)
            let slotX = gx + side * (tunnelWidth / 2 + roomSize.width / 2 + 6)

            // Cave-shaped placeholder (not built yet)
            let slot = SKShapeNode(path: cavePath(size: roomSize, wobble: 14))
            slot.fillColor = SKColor(red: 0.08, green: 0.05, blue: 0.03, alpha: 0.55)
            slot.strokeColor = SKColor(red: 0.35, green: 0.22, blue: 0.12, alpha: 0.5)
            slot.lineWidth = 1.5
            slot.position = CGPoint(x: slotX, y: y)
            slot.zRotation = side * CGFloat.random(in: -0.10...0.10)
            slot.name = "slot_\(i)"
            rContainer.addChild(slot)

            // Organic connector from gallery to the cave
            let connector = SKShapeNode()
            connector.zPosition = -5
            connector.strokeColor = tunnelColor
            connector.lineWidth = 13
            connector.lineCap = .round
            let cp = CGMutablePath()
            let fromX = gx + side * (tunnelWidth / 2)
            let toX = slotX - side * (roomSize.width / 2) * 0.7
            cp.move(to: CGPoint(x: fromX, y: y))
            cp.addQuadCurve(to: CGPoint(x: toX, y: y + side * 4),
                            control: CGPoint(x: (fromX + toX) / 2, y: y + side * 18))
            connector.path = cp
            rContainer.addChild(connector)
        }
    }

    // MARK: - Room updates

    private func updateRoomNodes() {
        guard let roomsContainer = roomsContainer else { return }
        for building in buildings {
            let slotName = "slot_\(building.buildingTypeID)"
            guard let slot = roomsContainer.childNode(withName: slotName) else { continue }

            if building.level > 0 {
                if roomNodes[building.buildingTypeID] == nil {
                    guard let imageName = chamberImageName(buildingTypeID: building.buildingTypeID,
                                                           level: building.level) else { continue }
                    let texture = SKTexture(imageNamed: imageName)

                    // Crop the generated image into an organic cave silhouette
                    let crop = SKCropNode()
                    crop.zPosition = 1
                    crop.position = slot.position
                    crop.zRotation = slot.zRotation
                    crop.name = "room_\(building.buildingTypeID)"

                    let sprite = SKSpriteNode(texture: texture)
                    sprite.size = roomSize

                    let mask = SKShapeNode(path: cavePath(size: roomSize, wobble: 10))
                    mask.fillColor = .white
                    mask.strokeColor = .clear

                    crop.maskNode = mask
                    crop.addChild(sprite)

                    roomsContainer.addChild(crop)
                    roomNodes[building.buildingTypeID] = crop

                    // Pop-in animation
                    crop.setScale(0.01)
                    let scaleAction = SKAction.scale(to: 1.0, duration: 0.45)
                    scaleAction.timingMode = .easeOut
                    crop.run(scaleAction)
                } else {
                    // Refresh texture if the level tier changed
                    if let crop = roomNodes[building.buildingTypeID] as? SKCropNode,
                       let sprite = crop.children.first as? SKSpriteNode,
                       let imageName = chamberImageName(buildingTypeID: building.buildingTypeID,
                                                        level: building.level) {
                        let newTexture = SKTexture(imageNamed: imageName)
                        if sprite.texture?.description != newTexture.description {
                            sprite.texture = newTexture
                            let pulse = SKAction.sequence([
                                SKAction.scale(to: 1.08, duration: 0.15),
                                SKAction.scale(to: 1.0, duration: 0.2)
                            ])
                            crop.run(pulse)
                        }
                    }
                }
                slot.alpha = 0
            } else {
                if let node = roomNodes.removeValue(forKey: building.buildingTypeID) {
                    node.removeFromParent()
                }
                slot.alpha = 1
            }
        }
    }
}
