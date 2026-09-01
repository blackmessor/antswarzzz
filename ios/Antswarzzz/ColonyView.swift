import SwiftUI
import SpriteKit

struct ColonyView: View {
    @ObservedObject var vm: DashboardViewModel

    @State private var scene: ColonyScene?
    @State private var lastScale: CGFloat = 1.0
    @State private var previousDrag: CGSize = .zero

    var body: some View {
        ZStack {
            if let scene = scene {
                SpriteView(scene: scene)
                    .ignoresSafeArea()
                    .gesture(
                        SimultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    guard let cam = scene.camera else { return }
                                    let delta = CGSize(
                                        width: value.translation.width - previousDrag.width,
                                        height: value.translation.height - previousDrag.height
                                    )
                                    previousDrag = value.translation
                                    cam.position.x -= delta.width
                                    cam.position.y += delta.height
                                }
                                .onEnded { _ in
                                    previousDrag = .zero
                                },
                            MagnificationGesture()
                                .onChanged { scale in
                                    guard let cam = scene.camera else { return }
                                    let delta = scale / lastScale
                                    cam.xScale = max(0.3, min(2.5, cam.xScale * delta))
                                    cam.yScale = cam.xScale
                                    lastScale = scale
                                }
                                .onEnded { _ in lastScale = 1.0 }
                        )
                    )
            } else {
                ProgressView()
                    .tint(.antAccent)
            }

            // HUD overlay — stats
            VStack {
                Spacer()
                HStack(spacing: 16) {
                    StatBadge(icon: "leaf.fill", value: vm.colony?.resources.food ?? 0, color: .antAccent)
                    StatBadge(icon: "hammer.fill", value: vm.colony?.resources.materials ?? 0, color: .antMuted)
                    StatBadge(icon: "ant.fill", value: vm.workerCount, color: .antText)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.bottom, 8)
            }
        }
        .onAppear {
            let s = ColonyScene(size: CGSize(width: UIScreen.main.bounds.width,
                                             height: UIScreen.main.bounds.height))
            s.scaleMode = .resizeFill
            s.buildings = vm.buildings
            scene = s
        }
        .onReceive(vm.$buildings) { newBuildings in
            scene?.buildings = newBuildings
        }
    }
}

// MARK: - HUD badge

struct StatBadge: View {
    let icon: String
    let value: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text("\(value)")
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(color)
    }
}