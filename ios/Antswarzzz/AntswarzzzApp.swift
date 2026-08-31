import SwiftUI

@main
struct AntswarzzzApp: App {
    @StateObject private var vm = DashboardViewModel()
    @AppStorage("username") private var username = ""
    @AppStorage("colonyID") private var colonyID: Int = 0
    @State private var isRegistered = false
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.antBg.ignoresSafeArea()
                if !isRegistered {
                    LoginView(vm: vm, username: $username, colonyID: $colonyID, isRegistered: $isRegistered)
                } else {
                    MainTabView(vm: vm, colonyID: $colonyID)
                        .onAppear {
                            vm.colonyID = colonyID
                            vm.startPolling()
                        }
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}
