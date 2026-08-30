import SwiftUI

// MARK: - Palette

extension Color {
    static let antBg      = Color(red: 0.039, green: 0.086, blue: 0.157)   // #0A1628
    static let antCard    = Color(red: 0.071, green: 0.153, blue: 0.267)   // #122644
    static let antAccent  = Color(red: 0.000, green: 0.831, blue: 0.667)   // #00D4AA
    static let antGold    = Color(red: 0.871, green: 0.722, blue: 0.529)   // #DEB887
    static let antText    = Color(red: 0.800, green: 0.867, blue: 0.933)   // #CCDDEE
    static let antMuted   = Color(red: 0.400, green: 0.500, blue: 0.600)
    static let antRed     = Color(red: 0.900, green: 0.300, blue: 0.300)
    static let antGreen   = Color(red: 0.200, green: 0.800, blue: 0.400)
    static let antOrange  = Color(red: 0.900, green: 0.600, blue: 0.200)
}

// MARK: - Shared Styles

struct AntCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(Color.antCard)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

extension View {
    func antCard() -> some View { modifier(AntCardStyle()) }
}

// MARK: - Resource Bar (top of Colony screen)

struct ResourceBar: View {
    let food: Int
    let materials: Int
    let tdc: Int
    var body: some View {
        HStack(spacing: 12) {
            ResourcePill(icon: "leaf.fill", value: food.formatted(), color: Color.antGreen)
            ResourcePill(icon: "cube.fill", value: materials.formatted(), color: Color.antGold)
            ResourcePill(icon: "map.fill", value: "\\(tdc) cm²", color: Color.antOrange)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.antBg.opacity(0.95))
    }
}

struct ResourcePill: View {
    let icon: String; let value: String; let color: Color
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption).foregroundStyle(color)
            Text(value).font(.caption.monospacedDigit().bold()).foregroundStyle(Color.antText)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Color.antCard)
        .clipShape(Capsule())
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let icon: String; let title: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(Color.antAccent)
            Text(title).font(.headline).foregroundStyle(Color.antAccent)
            Spacer()
        }
    }
}

// MARK: - Progress bar for construction timer

struct TimerBar: View {
    let total: Int; let remaining: Int
    var progress: Double { total > 0 ? 1.0 - Double(remaining) / Double(total) : 0 }
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(Color.antCard)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.antAccent)
                    .frame(width: geo.size.width * progress)
            }
        }
        .frame(height: 4)
    }
}
