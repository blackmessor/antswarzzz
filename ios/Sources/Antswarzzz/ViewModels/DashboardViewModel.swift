import Foundation
import Combine

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var colony: Colony?
    @Published var buildings: [ColonyBuilding] = []
    @Published var ants: [ColonyAnt] = []
    @Published var workerCount: Int = 0
    @Published var militaryCount: Int = 0
    @Published var colonyID: Int = 0
    @Published var isLoading = false
    @Published var error: String?

    // Worker sliders
    @Published var workersOnFood: Double = 0
    @Published var workersOnMaterials: Double = 0

    private let api = APIService.shared
    private var timer: Timer?

    func registerAndLoad(username: String) async {
        isLoading = true
        error = nil
        do {
            let resp = try await api.register(username: username)
            colonyID = resp.colonyID
            await refresh()
        } catch {
            self.error = "Inscription échouée: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func refresh() async {
        guard colonyID > 0 else { return }
        do {
            let state = try await api.getColony(colonyID)
            self.colony = state.colony
            self.buildings = state.buildings
            self.ants = state.ants
            self.workerCount = state.workerCount
            self.militaryCount = state.militaryCount ?? 0
            self.workersOnFood = Double(state.colony.workersOnFood)
            self.workersOnMaterials = Double(state.colony.workersOnMaterials)
            self.error = nil
        } catch {
            self.error = "Chargement: \(error.localizedDescription)"
        }
    }

    func commitWorkers() async {
        guard colonyID > 0 else { return }
        do {
            let _ = try await api.assignWorkers(
                colonyID: colonyID,
                food: Int(workersOnFood),
                materials: Int(workersOnMaterials)
            )
            await refresh()
        } catch {
            self.error = "Erreur assignation: \(error.localizedDescription)"
        }
    }

    func tick() async {
        guard colonyID > 0 else { return }
        do {
            let _ = try await api.forceTick(colonyID: colonyID)
            await refresh()
        } catch {
            self.error = "Erreur tick: \(error.localizedDescription)"
        }
    }

    func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
}
