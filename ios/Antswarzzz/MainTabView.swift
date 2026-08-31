import SwiftUI

struct MainTabView: View {
    @ObservedObject var vm: DashboardViewModel
    @Binding var colonyID: Int
    
    var body: some View {
        TabView {
            ColonyView(vm: vm)
                .tabItem { Label("Colonie", systemImage: "house.fill") }
            BuildingListView(vm: vm)
                .tabItem { Label("Bâtiments", systemImage: "building.2.fill") }
            BreedingListView(vm: vm)
                .tabItem { Label("Ponte", systemImage: "ant.fill") }
        }
        .tint(Color.antAccent)
        .toolbarBackground(Color.antBg, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
