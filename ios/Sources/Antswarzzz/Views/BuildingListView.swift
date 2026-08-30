import SwiftUI

struct BuildingListView: View {
    @ObservedObject var vm: DashboardViewModel
    @State private var selectedBuilding: Int?
    
    var constructing: ColonyBuilding? {
        vm.buildings.first(where: { $0.isConstructing })
    }
    var sortedBuildings: [ColonyBuilding] {
        vm.buildings.sorted { a, b in
            if a.isConstructing && !b.isConstructing { return true }
            if !a.isConstructing && b.isConstructing { return false }
            return a.buildingTypeID < b.buildingTypeID
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.antBg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        // Construction in progress
                        if let c = constructing, let name = buildingName(for: c.buildingTypeID) {
                            VStack(spacing: 8) {
                                SectionHeader(icon: "hammer.fill", title: "En construction")
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(name).font(.headline).foregroundStyle(Color.antText)
                                        Text("Passage au niv. \\(c.level + 1)")
                                            .font(.caption).foregroundStyle(Color.antMuted)
                                    }
                                    Spacer()
                                    Text(formatTime(c.constructionTimer))
                                        .font(.title3.monospacedDigit().bold())
                                        .foregroundStyle(Color.antAccent)
                                }
                                TimerBar(total: c.constructionTimer + 1800, remaining: c.constructionTimer)
                            }
                            .antCard()
                        }
                        
                        // Buildings list
                        SectionHeader(icon: "building.2.fill", title: "\\(vm.buildings.count) salles")
                        ForEach(sortedBuildings) { b in
                            BuildingRow(building: b) {
                                selectedBuilding = b.buildingTypeID
                                Task {
                                    await vm.upgradeBuilding(b.buildingTypeID)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Bâtiments")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    func formatTime(_ secs: Int) -> String {
        if secs <= 0 { return "Terminé" }
        let m = secs / 60
        let s = secs % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Building Row

struct BuildingRow: View {
    let building: ColonyBuilding
    let onUpgrade: () -> Void
    @State private var showUpgrade = false
    
    var name: String { buildingName(for: building.buildingTypeID) ?? "Salle \\(building.buildingTypeID)" }
    var levelTier: String {
        if building.level >= 15 { return "T4" }
        if building.level >= 10 { return "T3" }
        if building.level >= 5  { return "T2" }
        if building.level >= 1  { return "T1" }
        return ""
    }
    var tierColor: Color {
        if building.level >= 15 { return .purple }
        if building.level >= 10 { return .orange }
        if building.level >= 5  { return Color.antAccent }
        if building.level >= 1  { return Color.antGreen }
        return Color.antMuted
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Level badge
                ZStack {
                    Circle()
                        .fill(tierColor.opacity(0.2))
                        .frame(width: 40, height: 40)
                    Text("\\(building.level)")
                        .font(.caption.monospacedDigit().bold())
                        .foregroundStyle(tierColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.subheadline.bold()).foregroundStyle(Color.antText)
                    if !levelTier.isEmpty {
                        Text("Palier \\(levelTier)").font(.caption2).foregroundStyle(tierColor)
                    }
                    // Category badge
                    if let cat = buildingCategory(for: building.buildingTypeID) {
                        Text(cat).font(.caption2).foregroundStyle(Color.antMuted)
                    }
                }
                Spacer()
                if !building.isConstructing {
                    Button {
                        onUpgrade()
                    } label: {
                        Text("\\(costForLevel(building))")
                            .font(.caption.monospacedDigit())
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.antAccent.opacity(0.15))
                            .foregroundStyle(Color.antAccent)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
        }
        .background(Color.antCard)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    func costForLevel(_ b: ColonyBuilding) -> String {
        let lvl = b.level + 1
        let mats = Int64(2000) * Int64(1 << (lvl - 1))
        if mats > 1_000_000 { return "\\(mats / 1_000_000)M" }
        if mats > 1_000 { return "\\(mats / 1_000)k" }
        return "\\(mats)"
    }
    func buildingCategory(for id: Int) -> String? {
        switch id {
        case 1: return "B · Champignonnière"
        case 2,3: return "D · Entrepôt"
        case 4,5: return "A · Ponte"
        case 6,7: return "A · Recherche"
        case 8,9: return "C · Militaire"
        case 10,11: return "C · Défense"
        case 12,13: return "A · Ferme"
        default: return nil
        }
    }
}
