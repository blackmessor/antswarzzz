import SwiftUI

struct ColonyView: View {
    @ObservedObject var vm: DashboardViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color.antBg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        // Resource bar
                        if let c = vm.colony {
                            ResourceBar(food: c.resources.food, materials: c.resources.materials, tdc: c.tdcSize)
                        }

                        // Cross-section background with chamber overlays
                        ZStack {
                            // Background image (empty colony structure)
                            Image("BackgroundEmpty")
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            // Overlay each built chamber at its position
                            ForEach(vm.buildings.filter { $0.level > 0 }) { b in
                                if let imgName = chamberImageName(buildingTypeID: b.buildingTypeID, level: b.level) {
                                    Image(imgName)
                                        .resizable()
                                        .scaledToFit()
                                        .opacity(0.85)
                                        .animation(.easeInOut(duration: 0.5), value: b.level)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        // Workers quick-assign
                        workersSection
                            .padding()
                    }
                }
            }
            .navigationTitle(vm.colony?.name ?? "Colonie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await vm.tick() } } label: {
                        Image(systemName: "clock.arrow.2.circlepath")
                            .foregroundStyle(Color.antAccent)
                    }
                }
            }
        }
        .refreshable { await vm.refresh() }
    }

    var workersSection: some View {
        VStack(spacing: 12) {
            SectionHeader(icon: "person.2.fill", title: "Ouvrières — \(vm.workerCount)")
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("Nourriture").font(.caption).foregroundStyle(Color.antMuted)
                    Text("\(Int(vm.workersOnFood))").font(.title2.monospacedDigit().bold()).foregroundStyle(Color.antGreen)
                    Slider(value: $vm.workersOnFood, in: 0...Double(vm.workerCount), step: 1).tint(Color.antGreen)
                }
                VStack(spacing: 4) {
                    Text("Matériaux").font(.caption).foregroundStyle(Color.antMuted)
                    Text("\(Int(vm.workersOnMaterials))").font(.title2.monospacedDigit().bold()).foregroundStyle(Color.antGold)
                    Slider(value: $vm.workersOnMaterials, in: 0...Double(vm.workerCount), step: 1).tint(Color.antGold)
                }
            }
            Button { Task { await vm.commitWorkers() } } label: {
                Text("Appliquer").font(.headline).frame(maxWidth: .infinity).padding(10)
                    .background(Color.antAccent).foregroundStyle(Color.antBg)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .antCard()
    }
}