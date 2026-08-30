import Foundation

struct Resources: Codable {
    var food: Int
    var materials: Int
}

struct Colony: Codable, Identifiable {
    let id: Int
    let playerID: Int
    let name: String
    let tdcSize: Int
    let workersOnFood: Int
    let workersOnMaterials: Int
    let resources: Resources
    enum CodingKeys: String, CodingKey {
        case id, name, resources
        case playerID = "player_id"
        case tdcSize = "tdc_size"
        case workersOnFood = "workers_on_food"
        case workersOnMaterials = "workers_on_materials"
    }
}

struct ColonyBuilding: Codable, Identifiable {
    let id: Int
    let colonyID: Int
    let buildingTypeID: Int
    let level: Int
    let isConstructing: Bool
    let constructionTimer: Int
    enum CodingKeys: String, CodingKey {
        case id, level
        case colonyID = "colony_id"
        case buildingTypeID = "building_type_id"
        case isConstructing = "is_constructing"
        case constructionTimer = "construction_timer"
    }
}

struct ColonyAnt: Codable, Identifiable {
    let id: Int
    let colonyID: Int
    let antTypeID: Int
    let location: String
    let count: Int
    let cumulativeXP: Int
    enum CodingKeys: String, CodingKey {
        case id, location, count
        case colonyID = "colony_id"
        case antTypeID = "ant_type_id"
        case cumulativeXP = "cumulative_xp"
    }
}

struct ColonyStateResponse: Codable {
    let colony: Colony
    let buildings: [ColonyBuilding]
    let ants: [ColonyAnt]
    let workerCount: Int
    let militaryCount: Int?
    let breedQueue: [BreedQueueItem]?
    let activeBreed: ActiveBreedInfo?
    let research: [ResearchItem]?
    enum CodingKeys: String, CodingKey {
        case colony, buildings, ants, research
        case workerCount = "worker_count"
        case militaryCount = "military_count"
        case breedQueue = "breed_queue"
        case activeBreed = "active_breed"
    }
}

struct BreedQueueItem: Codable {
    let position: Int
    let antTypeID: Int
    enum CodingKeys: String, CodingKey {
        case position = "Position"
        case antTypeID = "AntTypeID"
    }
}

struct ActiveBreedInfo: Codable {
    let antTypeID: Int
    let timer: Int
    let queuePosition: Int
    enum CodingKeys: String, CodingKey {
        case antTypeID = "ant_type_id"
        case timer
        case queuePosition = "queue_position"
    }
}

struct ResearchItem: Codable {
    let researchTypeID: Int
    let level: Int
    let isResearching: Bool
    let researchingLevel: Int
    let researchTimer: Int
    enum CodingKeys: String, CodingKey {
        case researchTypeID = "ResearchTypeID"
        case level = "Level"
        case isResearching = "IsResearching"
        case researchingLevel = "ResearchingLevel"
        case researchTimer = "ResearchTimer"
    }
}

struct RegisterResponse: Codable {
    let playerID: Int
    let colonyID: Int
    let username: String
    enum CodingKeys: String, CodingKey {
        case playerID = "player_id"
        case colonyID = "colony_id"
        case username
    }
}

struct ActionResponse: Codable {
    let status: String?
    let error: String?
}

struct BuildingType: Identifiable {
    let id: Int; let name: String; let category: String
}

let buildingTypes: [BuildingType] = [
    .init(id: 1, name: "Champignonnière", category: "B"),
    .init(id: 2, name: "Entrepôt nourriture", category: "D"),
    .init(id: 3, name: "Entrepôt matériaux", category: "D"),
    .init(id: 4, name: "Couveuse", category: "A"),
    .init(id: 5, name: "Solarium", category: "A"),
    .init(id: 6, name: "Laboratoire", category: "A"),
    .init(id: 7, name: "Salle d'analyse", category: "A"),
    .init(id: 8, name: "Salle de combat", category: "C"),
    .init(id: 9, name: "Caserne", category: "C"),
    .init(id: 10, name: "Dôme", category: "C"),
    .init(id: 11, name: "Loge Impériale", category: "C"),
    .init(id: 12, name: "Étable à pucerons", category: "A"),
    .init(id: 13, name: "Étable à cochenilles", category: "A"),
]

func buildingName(for id: Int) -> String {
    buildingTypes.first(where: { $0.id == id })?.name ?? "Bâtiment \(id)"
}

let antTypeNames: [Int: String] = [
    0:"Ouvrière", 1:"JSN", 2:"SN", 3:"NE", 4:"JS", 5:"S", 6:"SE",
    7:"C", 8:"CE", 9:"A", 10:"AE", 11:"Tk", 12:"TkE", 13:"Tu", 14:"TuE"
]

func antName(for id: Int) -> String { antTypeNames[id] ?? "Type \(id)" }
