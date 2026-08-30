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
                        
                        // Cross-section image placeholder
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red:0.20,green:0.35,blue:0.15), Color.antBg],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                                .frame(height: 420)
                            
                            VStack(spacing: 20) {
                                Image(systemName: "ant.fill")
                                    .font(.system(size: 50))
                                    .foregroundStyle(Color.antAccent.opacity(0.3))
                                Text("Coupe transversale")
                                    .font(.headline)
                                    .foregroundStyle(Color.antMuted)
                                Text("L'image de la fourmilière
apparaîtra ici")
                                    .font(.caption)
                                    .foregroundStyle(Color.antMuted.opacity(0.6))
                                    .multilineTextAlignment(.center)
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
            SectionHeader(icon: "person.2.fill", title: "Ouvrières — \\(vm.workerCount)")
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("Nourriture").font(.caption).foregroundStyle(Color.antMuted)
                    Text("\\(Int(vm.workersOnFood))").font(.title2.monospacedDigit().bold()).foregroundStyle(Color.antGreen)
                    Slider(value: $vm.workersOnFood, in: 0...Double(vm.workerCount), step: 1).tint(Color.antGreen)
                }
                VStack(spacing: 4) {
                    Text("Matériaux").font(.caption).foregroundStyle(Color.antMuted)
                    Text("\\(Int(vm.workersOnMaterials))").font(.title2.monospacedDigit().bold()).foregroundStyle(Color.antGold)
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
