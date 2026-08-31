import Foundation
import Combine

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var colony: Colony?
    @Published var buildings: [ColonyBuilding] = []
    @Published var ants: [ColonyAnt] = []
    @Published var colonyID: Int = 0
    @Published var isLoading = false
    @Published var error: String?
    @Published var activeBreed: ActiveBreedInfo?
    @Published var militaryCount: Int = 0

    @Published var workerCount: Int = 0
    @Published var workersOnFood: Double = 0
    @Published var workersOnMaterials: Double = 0

    private let api = APIService.shared
    private var timer: Timer?

    func registerAndLoad(username: String) async {
        isLoading = true; error = nil
        do {
            print("[VM] registerAndLoad: username=\(username)")
            let resp = try await api.register(username: username)
            print("[VM] register succeeded: player=\(resp.playerID) colony=\(resp.colonyID)")
            colonyID = resp.colonyID
            await refresh()
            print("[VM] refresh after register done, colony=\(colony?.name ?? "nil")")
        } catch {
            print("[VM] registerAndLoad ERROR: \(error)")
            self.error = "Erreur: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func refresh() async {
        guard colonyID > 0 else { return }
        do {
            print("[VM] refresh colonyID=\(colonyID)")
            let state = try await api.getColony(colonyID)
            self.colony = state.colony
            self.buildings = state.buildings
            self.ants = state.ants
            self.workerCount = state.workerCount
            self.militaryCount = state.militaryCount ?? 0
            self.workersOnFood = Double(state.colony.workersOnFood)
            self.workersOnMaterials = Double(state.colony.workersOnMaterials)
            self.activeBreed = state.activeBreed
            self.error = nil
            print("[VM] refresh done: buildings=\(state.buildings.count), ants=\(state.ants.count)")
        } catch {
            print("[VM] refresh ERROR: \(error)")
            self.error = "Erreur: \(error.localizedDescription)"
        }
    }

    func commitWorkers() async {
        guard colonyID > 0 else { return }
        do {
            _ = try await api.assignWorkers(colonyID: colonyID, food: Int(workersOnFood), materials: Int(workersOnMaterials))
            await refresh()
        } catch {
            self.error = "Erreur: \(error.localizedDescription)"
        }
    }

    func upgradeBuilding(_ buildingTypeID: Int) async {
        do {
            let body: [String: Any] = ["action": "upgrade_building", "building_type_id": buildingTypeID]
            _ = try await api.post("/api/colony/\(colonyID)", body: body)
            await refresh()
        } catch {
            self.error = "Erreur: \(error.localizedDescription)"
        }
    }

    func queueBreed(_ antTypeID: Int) async {
        do {
            let body: [String: Any] = ["action": "queue", "ant_type_id": antTypeID]
            _ = try await api.post("/api/breeding/\(colonyID)", body: body)
            await refresh()
        } catch {
            self.error = "Erreur: \(error.localizedDescription)"
        }
    }

    func tick() async {
        guard colonyID > 0 else { return }
        do {
            _ = try await api.forceTick(colonyID: colonyID)
            await refresh()
        } catch {
            self.error = "Erreur: \(error.localizedDescription)"
        }
    }

    func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }
    func stopPolling() { timer?.invalidate(); timer = nil }
}