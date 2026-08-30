import SwiftUI

struct BreedingListView: View {
    @ObservedObject var vm: DashboardViewModel
    
    var activeBreed: ActiveBreedInfo? { vm.activeBreed }
    
    let antTypes: [(id: Int, name: String, abbr: String, cost: Int, time: Int)] = [
        (0, "Ouvrière", "Wrk", 5, 60),
        (1, "Jeune Soldate Naine", "JSN", 10, 300),
        (2, "Soldate Naine", "SN", 14, 450),
        (4, "Jeune Soldate", "JS", 16, 740),
        (5, "Soldate", "S", 22, 1000),
        (7, "Concierge", "C", 30, 1410),
        (9, "Artilleuse", "A", 28, 1440),
        (11, "Tank", "Tk", 45, 1860),
        (13, "Tueuse", "Tu", 60, 2740),
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.antBg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        // Active breed
                        if let ab = activeBreed {
                            VStack(spacing: 8) {
                                SectionHeader(icon: "clock.fill", title: "Ponte en cours")
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(antName(for: ab.antTypeID)).font(.headline).foregroundStyle(Color.antText)
                                        Text("Position \\(ab.queuePosition) dans la file")
                                            .font(.caption).foregroundStyle(Color.antMuted)
                                    }
                                    Spacer()
                                    Text(formatTime(ab.timer))
                                        .font(.title3.monospacedDigit().bold())
                                        .foregroundStyle(Color.antAccent)
                                }
                                TimerBar(total: 300, remaining: ab.timer)
                            }
                            .antCard()
                        }
                        
                        // My ants
                        if !vm.ants.isEmpty {
                            SectionHeader(icon: "ant.fill", title: "Peuple — \\(vm.workerCount) ouvrières, \\(vm.militaryCount) militaires")
                            ForEach(vm.ants.filter { $0.count > 0 }) { a in
                                HStack(spacing: 10) {
                                    Text(antName(for: a.antTypeID)).font(.subheadline).foregroundStyle(Color.antText)
                                    Spacer()
                                    Text("\\(a.count)").font(.subheadline.monospacedDigit().bold()).foregroundStyle(Color.antAccent)
                                    if a.cumulativeXP > 0 {
                                        Text("⭐\\(a.cumulativeXP)").font(.caption2).foregroundStyle(Color.antGold)
                                    }
                                }
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(Color.antCard)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .padding(.horizontal)
                        }
                        
                        // Breedable ants list
                        SectionHeader(icon: "plus.circle.fill", title: "Lancer une ponte")
                        ForEach(antTypes, id: \.id) { ant in
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ant.name).font(.subheadline.bold()).foregroundStyle(Color.antText)
                                    Text("\\(ant.abbr) · Coût: \\(ant.foodCost) nourr. · \\(formatTime(ant.time))")
                                        .font(.caption2).foregroundStyle(Color.antMuted)
                                }
                                Spacer()
                                Button {
                                    Task { await vm.queueBreed(ant.id) }
                                } label: {
                                    Text("Pondre").font(.caption.bold())
                                        .padding(.horizontal, 12).padding(.vertical, 6)
                                        .background(Color.antAccent.opacity(0.15))
                                        .foregroundStyle(Color.antAccent)
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Color.antCard)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                }
            }
            .navigationTitle("Ponte")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    func formatTime(_ secs: Int) -> String {
        if secs <= 0 { return "Terminé" }
        if secs >= 3600 { return "\\(secs / 3600)h\\((secs % 3600) / 60)m" }
        let m = secs / 60; let s = secs % 60
        return "\\(m)m\\(s)s"
    }
}
