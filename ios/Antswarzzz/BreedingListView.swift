import SwiftUI

struct BreedingListView: View {
    @ObservedObject var vm: DashboardViewModel

    var activeBreed: ActiveBreedInfo? { vm.activeBreed }

    // All breedable ant types (elite forms come via evolution)
    private let antTypes: [AntBreedOption] = [
        AntBreedOption(id: 0, name: "Ouvrière", abbr: "Wrk", cost: 5, time: 60),
        AntBreedOption(id: 1, name: "Jeune Soldate Naine", abbr: "JSN", cost: 10, time: 300),
        AntBreedOption(id: 2, name: "Soldate Naine", abbr: "SN", cost: 14, time: 450),
        AntBreedOption(id: 4, name: "Jeune Soldate", abbr: "JS", cost: 16, time: 740),
        AntBreedOption(id: 5, name: "Soldate", abbr: "S", cost: 22, time: 1000),
        AntBreedOption(id: 7, name: "Concierge", abbr: "C", cost: 30, time: 1410),
        AntBreedOption(id: 9, name: "Artilleuse", abbr: "A", cost: 28, time: 1440),
        AntBreedOption(id: 10, name: "Artilleuse d'Élite", abbr: "AE", cost: 35, time: 1520),
        AntBreedOption(id: 11, name: "Tank", abbr: "Tk", cost: 45, time: 1860),
        AntBreedOption(id: 13, name: "Tueuse", abbr: "Tu", cost: 60, time: 2740),
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
                                        Text("Position \(ab.queuePosition) dans la file")
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
                            SectionHeader(icon: "ant.fill", title: "Peuple — \(vm.workerCount) ouvrières, \(vm.militaryCount) militaires")
                            ForEach(vm.ants.filter { $0.count > 0 }) { a in
                                HStack(spacing: 10) {
                                    Text(antName(for: a.antTypeID)).font(.subheadline).foregroundStyle(Color.antText)
                                    Spacer()
                                    Text("\(a.count)").font(.subheadline.monospacedDigit().bold()).foregroundStyle(Color.antAccent)
                                    if a.cumulativeXP > 0 {
                                        Text("⭐\(a.cumulativeXP)").font(.caption2).foregroundStyle(Color.antGold)
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
                        ForEach(antTypes) { ant in
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ant.name).font(.subheadline.bold()).foregroundStyle(Color.antText)
                                    Text("\(ant.abbr) · Coût: \(ant.cost) nourr. · \(formatTime(ant.time))")
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
        if secs >= 3600 { return "\(secs / 3600)h\((secs % 3600) / 60)m" }
        let m = secs / 60; let s = secs % 60
        return "\(m)m\(s)s"
    }
}

// MARK: - Model

struct AntBreedOption: Identifiable {
    let id: Int
    let name: String
    let abbr: String
    let cost: Int
    let time: Int
}
