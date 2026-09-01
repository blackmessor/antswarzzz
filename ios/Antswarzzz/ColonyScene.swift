import SpriteKit
import SwiftUI

/// SpriteKit scene rendering the ant colony cross-section.
/// Data-driven: reads buildings from a binding, creates/updates room nodes accordingly.
final class ColonyScene: SKScene {

    // MARK: - Configuration

    private let tunnelWidth: CGFloat = 60
    private let roomBaseWidth: CGFloat = 140
    private let roomBaseHeight: CGFloat = 100
    private let verticalSpacing: CGFloat = 20
    private let earthColor = SKColor(red: 0.17, green: 0.11, blue: 0.07, alpha: 1.0)   // #2B1B17
    private let tunnelColor = SKColor(red: 0.12, green: 0.07, blue: 0.04, alpha: 1.0)
    private let chamberEmptyColor = SKColor(red: 0.08, green: 0.05, blue: 0.03, alpha: 1.0)
    private let roomColors: [Int: SKColor] = [
        1:  SKColor(red: 0.40, green: 0.30, blue: 0.10, alpha: 1.0), // Champignonnière — amber
        2:  SKColor(red: 0.55, green: 0.42, blue: 0.14, alpha: 1.0), // Entrepôt nourriture — gold
        3:  SKColor(red: 0.45, green: 0.45, blue: 0.50, alpha: 1.0), // Entrepôt matériaux — grey
        4:  SKColor(red: 0.60, green: 0.50, blue: 0.55, alpha: 1.0), // Couveuse — pink
        5:  SKColor(red: 0.70, green: 0.60, blue: 0.20, alpha: 1.0), // Solarium — yellow
        6:  SKColor(red: 0.30, green: 0.60, blue: 0.70, alpha: 1.0), // Labo — cyan
        7:  SKColor(red: 0.50, green: 0.30, blue: 0.60, alpha: 1.0), // Salle d'analyse — purple
        8:  SKColor(red: 0.80, green: 0.20, blue: 0.20, alpha: 1.0), // Salle de combat — red
        9:  SKColor(red: 0.70, green: 0.35, blue: 0.15, alpha: 1.0), // Caserne — orange
        10: SKColor(red: 0.20, green: 0.50, blue: 0.30, alpha: 1.0), // Dôme — green
        11: SKColor(red: 0.70, green: 0.60, blue: 0.10, alpha: 1.0), // Loge Impériale — gold
        12: SKColor(red: 0.60, green: 0.80, blue: 0.40, alpha: 1.0), // Étable pucerons — lime
        13: SKColor(red: 0.50, green: 0.40, blue: 0.60, alpha: 1.0), // Étable cochenilles — violet
    ]

    // MARK: - Data binding

    /// Called by the view to push building state into the scene.
    var buildings: [ColonyBuilding] = [] {
        didSet { updateRoomNodes() }
    }

    // MARK: - Node containers

    private var earthNode: SKShapeNode!
    private var cameraNode: SKCameraNode!
    private var roomsContainer: SKNode?
    private var tunnelContainer: SKNode?

    /// Room slot → its SpriteKit node (keyed by building_type_id)
    private var roomNodes: [Int: SKNode] = [:]

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = earthColor
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        setupCamera()
        setupEarth()
        setupTunnel()
        setupRoomSlots()

        // Rooms may have been pushed before didMove — apply now
        updateRoomNodes()
    }

    // MARK: - Setup

    private func setupCamera() {
        cameraNode = SKCameraNode()
        camera = cameraNode
        addChild(cameraNode)
        cameraNode.position = .zero
    }

    private func setupEarth() {
        // Large earth background rectangle
        earthNode = SKShapeNode(rect: CGRect(x: -frame.width, y: -2000, width: frame.width * 2, height: 4000))
        earthNode.fillColor = earthColor
        earthNode.strokeColor = .clear
        earthNode.zPosition = -10
        addChild(earthNode)
    }

    private func setupTunnel() {
        let container = SKNode()
        container.zPosition = -5
        addChild(container)
        tunnelContainer = container

        // Draw vertical tunnel — a dark rectangle in the center
        let tunnel = SKShapeNode(rect: CGRect(
            x: -tunnelWidth / 2,
            y: -1600,
            width: tunnelWidth,
            height: 3200
        ))
        tunnel.fillColor = tunnelColor
        tunnel.strokeColor = SKColor(red: 0.25, green: 0.15, blue: 0.08, alpha: 1.0)
        tunnel.lineWidth = 2
        container.addChild(tunnel)

        // Tunnel wall texture lines
        for i in stride(from: -1550, through: 1550, by: 60) {
            let line = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -tunnelWidth / 2 - 5, y: CGFloat(i)))
            path.addLine(to: CGPoint(x: -tunnelWidth / 2 + 5, y: CGFloat(i) + 3))
            line.path = path
            line.strokeColor = SKColor(red: 0.3, green: 0.18, blue: 0.1, alpha: 0.5)
            line.lineWidth = 1
            container.addChild(line)

            let lineR = SKShapeNode()
            let pathR = CGMutablePath()
            pathR.move(to: CGPoint(x: tunnelWidth / 2 + 5, y: CGFloat(i)))
            pathR.addLine(to: CGPoint(x: tunnelWidth / 2 - 5, y: CGFloat(i) + 3))
            lineR.path = pathR
            lineR.strokeColor = SKColor(red: 0.3, green: 0.18, blue: 0.1, alpha: 0.5)
            lineR.lineWidth = 1
            container.addChild(lineR)
        }
    }

    private func setupRoomSlots() {
        let rContainer = SKNode()
        rContainer.zPosition = 0
        addChild(rContainer)
        roomsContainer = rContainer

        // Create 13 empty room slots — alternating left/right
        for i in 1...13 {
            let side: CGFloat = (i % 2 == 0) ? 1 : -1  // alternate sides
            let y = CGFloat(1200 - (i - 1) * 200)       // top to bottom

            // Empty chamber outline
            let emptyNode = SKShapeNode(ellipseOf: CGSize(width: roomBaseWidth, height: roomBaseHeight))
            emptyNode.fillColor = chamberEmptyColor
            emptyNode.strokeColor = SKColor(red: 0.2, green: 0.12, blue: 0.06, alpha: 1.0)
            emptyNode.lineWidth = 1.5
            emptyNode.position = CGPoint(x: side * (tunnelWidth / 2 + roomBaseWidth / 2 + 10), y: y)
            emptyNode.name = "slot_\(i)"
            emptyNode.alpha = 0.4
            rContainer.addChild(emptyNode)

            // Connector tunnel
            let connector = SKShapeNode(rect: CGRect(
                x: side > 0 ? 0 : -roomBaseWidth / 2 - 10,
                y: y - 6,
                width: roomBaseWidth / 2 + 10,
                height: 12
            ))
            connector.fillColor = tunnelColor
            connector.strokeColor = .clear
            connector.position = CGPoint(x: side * (tunnelWidth / 2), y: 0)
            tunnelContainer?.addChild(connector)
        }
    }

    // MARK: - Room updates

    private func updateRoomNodes() {
        guard let roomsContainer = roomsContainer else { return }
        for building in buildings {
            let slotName = "slot_\(building.buildingTypeID)"
            guard let slot = roomsContainer.childNode(withName: slotName) else { continue }

            if building.level > 0 {
                // Room is built — show it
                let color = roomColors[building.buildingTypeID] ?? .gray
                let alpha: CGFloat = building.isConstructing ? 0.5 : 1.0

                if let existing = roomNodes[building.buildingTypeID] {
                    // Update existing node
                    if let shape = existing as? SKShapeNode {
                        shape.fillColor = color
                        shape.alpha = alpha
                    }
                    // Update level decorations
                    updateDecorations(for: existing, building: building)
                } else {
                    // Create new room node
                    let room = SKShapeNode(ellipseOf: CGSize(width: roomBaseWidth, height: roomBaseHeight))
                    room.fillColor = color
                    room.strokeColor = SKColor.white.withAlphaComponent(0.2)
                    room.lineWidth = 1.5
                    room.position = slot.position
                    room.zPosition = 1
                    room.name = "room_\(building.buildingTypeID)"
                    room.alpha = alpha
                    roomsContainer.addChild(room)
                    roomNodes[building.buildingTypeID] = room

                    // Pop-in animation
                    room.setScale(0.01)
                    let scaleAction = SKAction.scale(to: 1.0, duration: 0.4)
                    scaleAction.timingMode = .easeOut
                    room.run(scaleAction)

                    // Initial decorations
                    updateDecorations(for: room, building: building)
                }
                slot.alpha = 0 // hide empty slot
            } else {
                // Room not built
                if let existing = roomNodes[building.buildingTypeID] {
                    existing.removeFromParent()
                    roomNodes.removeValue(forKey: building.buildingTypeID)
                }
                slot.alpha = 0.4 // show empty slot
            }
        }
    }

    private func updateDecorations(for roomNode: SKNode, building: ColonyBuilding) {
        // Remove old decoration children
        roomNode.children.filter { $0.name?.hasPrefix("deco_") == true }.forEach { $0.removeFromParent() }

        let level = building.level
        let color = roomColors[building.buildingTypeID] ?? .gray

        // Small dots/circles representing extra detail at higher levels
        let decoCount: Int
        if level >= 15 { decoCount = 12 }
        else if level >= 10 { decoCount = 8 }
        else if level >= 5 { decoCount = 5 }
        else { decoCount = 2 }

        for i in 0..<decoCount {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let radius = CGFloat.random(in: 15...(roomBaseHeight / 2 - 10))
            let dot = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...5))
            dot.fillColor = color.withAlphaComponent(0.6)
            dot.strokeColor = .clear
            dot.position = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            dot.name = "deco_\(i)"
            dot.zPosition = 2
            roomNode.addChild(dot)
        }

        // Level label
        if level > 0 {
            let label = SKLabelNode(text: "Lv\(level)")
            label.fontName = "Helvetica"
            label.fontSize = 11
            label.fontColor = SKColor(red: 0.87, green: 0.72, blue: 0.53, alpha: 1.0) // #DEB887
            label.position = CGPoint(x: 0, y: -roomBaseHeight / 2 - 14)
            label.name = "deco_label"
            label.zPosition = 3
            roomNode.addChild(label)
        }
    }

    // MARK: - Touch handling (pan / zoom)

    override func didChangeSize(_ oldSize: CGSize) {
        cameraNode?.position = .zero
    }
}