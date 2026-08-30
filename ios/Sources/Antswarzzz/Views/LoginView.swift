import SwiftUI

struct LoginView: View {
    @ObservedObject var vm: DashboardViewModel
    @Binding var username: String
    @Binding var colonyID: Int
    @Binding var isRegistered: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "ant.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.antAccent)
            Text("Antswarzzz")
                .font(.system(size: 36, weight: .bold, design: .serif))
                .foregroundStyle(Color.antText)
            Text("Bâtis ta colonie souterraine")
                .font(.subheadline)
                .foregroundStyle(Color.antMuted)
            
            VStack(spacing: 12) {
                TextField("Nom de joueur", text: $username)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(Color.antCard)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(Color.antText)
                    .frame(maxWidth: 300)
                
                Button {
                    Task {
                        await vm.registerAndLoad(username: username)
                        if vm.error == nil, let c = vm.colony {
                            colonyID = c.id
                            isRegistered = true
                        }
                    }
                } label: {
                    Text("Créer ma colonie")
                        .font(.headline)
                        .frame(maxWidth: 300)
                        .padding()
                        .background(Color.antAccent)
                        .foregroundStyle(Color.antBg)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(username.isEmpty || vm.isLoading)
            }
            
            if vm.isLoading {
                ProgressView().tint(Color.antAccent)
            }
            if let err = vm.error {
                Text(err).font(.caption).foregroundStyle(Color.antRed)
            }
            Spacer()
        }
    }
}
