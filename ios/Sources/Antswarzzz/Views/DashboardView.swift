import SwiftUI

struct DashboardView: View {
    @StateObject var vm = DashboardViewModel()
    @State var username = ""
    @State var isRegistered = false

    var body: some View {
        NavigationStack {
            if !isRegistered {
                loginView
            } else if let colony = vm.colony {
                colonyView(colony)
            } else if vm.isLoading {
                ProgressView("Chargement…")
            } else {
                ContentUnavailableView("Aucune colonie", systemImage: "ant")
            }
        }
    }

    // MARK: - Login

    var loginView: some View {
        VStack(spacing: 20) {
            Image(systemName: "ant.fill")
                .font(.system(size: 60))
                .foregroundStyle(.brown)
            Text("Antswarzzz")
                .font(.largeTitle.bold())
            TextField("Nom de joueur", text: $username)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 300)
            Button("Créer ma colonie") {
                Task {
                    await vm.registerAndLoad(username: username)
                    if vm.error == nil {
                        isRegistered = true
                        vm.startPolling()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(username.isEmpty || vm.isLoading)
            if let err = vm.error {
                Text(err).foregroundStyle(.red).font(.caption)
            }
        }
        .padding()
    }

    // MARK: - Colony Dashboard

    func colonyView(_ colony: Colony) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Resources
                resourcesCard(colony)
                // Workers
                workersCard(colony)
                // Buildings
                buildingsCard
                // Army
                armyCard
                // Actions
                actionsCard
            }
            .padding()
        }
        .navigationTitle(colony.name)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button { Task { await vm.tick() } } label: {
                    Image(systemName: "forward.frame.fill")
                }
            }
        }
        .refreshable { await vm.refresh() }
    }

    // MARK: - Cards

    func resourcesCard(_ colony: Colony) -> some View {
        HStack(spacing: 16) {
            StatCard(icon: "leaf.fill", value: colony.resources.food, label: "Nourriture", color: .green)
            StatCard(icon: "cube.fill", value: colony.resources.materials, label: "Matériaux", color: .brown)
            StatCard(icon: "map.fill", value: colony.tdcSize, label: "TDC (cm²)", color: .orange)
        }
    }

    func workersCard(_ colony: Colony) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Ouvrières — \(vm.workerCount) dispo", systemImage: "person.2.fill")
                .font(.headline)
            VStack(spacing: 4) {
                HStack {
                    Text("Nourriture: \(Int(vm.workersOnFood))")
                    Slider(value: $vm.workersOnFood, in: 0...Double(vm.workerCount), step: 1)
                }
                HStack {
                    Text("Matériaux: \(Int(vm.workersOnMaterials))")
                    Slider(value: $vm.workersOnMaterials, in: 0...Double(vm.workerCount), step: 1)
                }
            }
            Button("Appliquer") { Task { await vm.commitWorkers() } }
                .buttonStyle(.bordered)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    var buildingsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Bâtiments — \(vm.buildings.count)", systemImage: "building.2.fill")
                .font(.headline)
            ForEach(vm.buildings) { b in
                HStack {
                    Text(buildingName(for: b.buildingTypeID))
                    Spacer()
                    Text("Niv. \(b.level)")
                        .foregroundStyle(.secondary)
                    if b.isConstructing {
                        Image(systemName: "hammer.fill")
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.vertical, 2)
                if b.buildingTypeID != vm.buildings.last?.buildingTypeID {
                    Divider()
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    var armyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Armée — \(vm.militaryCount) militaires", systemImage: "shield.fill")
                .font(.headline)
            ForEach(vm.ants.filter { $0.antTypeID > 0 && $0.count > 0 }) { a in
                HStack {
                    Text(antName(for: a.antTypeID))
                    Spacer()
                    Text("\(a.count)")
                        .foregroundStyle(.secondary)
                    if a.cumulativeXP > 0 {
                        Text("⭐\(a.cumulativeXP)")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                    Text(a.location)
                        .font(.caption)
                        .foregroundStyle(a.location == "home" ? .green : .orange)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    var actionsCard: some View {
        HStack(spacing: 12) {
            Button { Task { await vm.tick() } } label: {
                Label("Tick (+30 min)", systemImage: "clock.arrow.2.circlepath")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - StatCard

struct StatCard: View {
    let icon: String
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value.formatted())
                .font(.title.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
