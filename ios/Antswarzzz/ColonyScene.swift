import SpriteKit
import SwiftUI

/// SpriteKit scene rendering the ant colony cross-section.
/// Data-driven: reads buildings from a binding, loads the matching chamber image.
final class ColonyScene: SKScene {

    // MARK: - Configuration

    private let tunnelWidth: CGFloat = 80
    private let roomSize = CGSize(width: 190, height: 130)
    private let verticalSpacing: CGFloat = 210
    private let earthColor = SKColor(red: 0.17, green: 0.11, blue: 0.07, alpha: 1.0)   // #2B1B17

    // MARK: - Data binding

    var buildings: [ColonyBuilding] = [] {
        didSet { updateRoomNodes() }
    }

    // MARK: - Node containers

    private var cameraNode: SKCameraNode!
    private var roomsContainer: SKNode?
    private var backgroundNode: SKSpriteNode?
    private var roomNodes: [Int: SKNode] = [:]
    private var didSetup = false

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = earthColor
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        setupCamera()
        setupBackground()
        setupTunnel()
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
        cameraNode.setScale(0.8)
    }

    private func setupBackground() {
        // Use the generated empty-anthill background as the cross-section base
        let texture = SKTexture(imageNamed: "BackgroundEmpty")
        let bg = SKSpriteNode(texture: texture)
        bg.size = CGSize(width: frame.width * 1.4, height: frame.height * 1.6)
        bg.zPosition = -20
        bg.position = CGPoint(x: 0, y: -80)
        addChild(bg)
        backgroundNode = bg
    }

    private func setupTunnel() {
        let container = SKNode()
        container.zPosition = -10
        addChild(container)

        // Vertical gallery — dark tunnel in the center
        let tunnel = SKShapeNode(rect: CGRect(
            x: -tunnelWidth / 2,
            y: -1600,
            width: tunnelWidth,
            height: 3200
        ))
        tunnel.fillColor = SKColor(red: 0.10, green: 0.06, blue: 0.03, alpha: 1.0)
        tunnel.strokeColor = SKColor(red: 0.25, green: 0.15, blue: 0.08, alpha: 1.0)
        tunnel.lineWidth = 2
        container.addChild(tunnel)
    }

    private func setupRoomSlots() {
        let rContainer = SKNode()
        rContainer.zPosition = 0
        addChild(rContainer)
        roomsContainer = rContainer

        // 13 room slots — alternating left/right along the central gallery
        for i in 1...13 {
            let side: CGFloat = (i % 2 == 0) ? 1 : -1
            let y = 650 - CGFloat(i - 1) * verticalSpacing

            // Empty chamber outline (dashed placeholder)
            let slot = SKShapeNode(rectOf: roomSize, cornerRadius: 14)
            slot.fillColor = SKColor(red: 0.08, green: 0.05, blue: 0.03, alpha: 0.6)
            slot.strokeColor = SKColor(red: 0.35, green: 0.22, blue: 0.12, alpha: 0.5)
            slot.lineWidth = 1.5
            slot.position = CGPoint(x: side * (tunnelWidth / 2 + roomSize.width / 2 + 15), y: y)
            slot.name = "slot_\(i)"
            rContainer.addChild(slot)

            // Connector tunnel from gallery to the room
            let connector = SKShapeNode(rect: CGRect(
                x: side > 0 ? 0 : -roomSize.width / 2 - 10,
                y: -6,
                width: roomSize.width / 2 + 10,
                height: 12
            ))
            connector.fillColor = SKColor(red: 0.10, green: 0.06, blue: 0.03, alpha: 1.0)
            connector.strokeColor = .clear
            connector.position = CGPoint(x: side * (tunnelWidth / 2), y: 0)
            connector.zPosition = -5
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
                // Room is built — load its chamber image for this level tier
                if roomNodes[building.buildingTypeID] == nil {
                    guard let imageName = chamberImageName(buildingTypeID: building.buildingTypeID,
                                                           level: building.level) else { continue }
                    let texture = SKTexture(imageNamed: imageName)
                    let node = SKSpriteNode(texture: texture)
                    node.size = roomSize
                    node.position = slot.position
                    node.zPosition = 1
                    node.name = "room_\(building.buildingTypeID)"
                    roomsContainer.addChild(node)
                    roomNodes[building.buildingTypeID] = node

                    // Pop-in animation
                    node.setScale(0.01)
                    let scaleAction = SKAction.scale(to: 1.0, duration: 0.45)
                    scaleAction.timingMode = .easeOut
                    node.run(scaleAction)
                } else {
                    // Room exists — refresh image if the tier changed
                    if let node = roomNodes[building.buildingTypeID] as? SKSpriteNode,
                       let imageName = chamberImageName(buildingTypeID: building.buildingTypeID,
                                                        level: building.level) {
                        let newTexture = SKTexture(imageNamed: imageName)
                        if node.texture?.description != newTexture.description {
                            node.texture = newTexture
                            // Small pulse to show the upgrade
                            let pulse = SKAction.sequence([
                                SKAction.scale(to: 1.08, duration: 0.15),
                                SKAction.scale(to: 1.0, duration: 0.2)
                            ])
                            node.run(pulse)
                        }
                    }
                }
                slot.alpha = 0 // hide empty placeholder
            } else {
                // Not built — remove any room image, show the placeholder
                if let node = roomNodes.removeValue(forKey: building.buildingTypeID) {
                    node.removeFromParent()
                }
                slot.alpha = 1
            }
        }
    }
}
