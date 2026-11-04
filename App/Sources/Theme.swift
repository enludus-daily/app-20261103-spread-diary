import SwiftUI

/// 見た目の決まり（色・角丸・影）。アイコンのコーラル〜ピンクに合わせる。
enum Theme {
    static let coral = Color(red: 1.0, green: 0.48, blue: 0.33)
    static let pink = Color(red: 0.91, green: 0.29, blue: 0.43)
    static let indigo = Color(red: 0.24, green: 0.25, blue: 0.56)
    static let mint = Color(red: 0.18, green: 0.69, blue: 0.47)
    static let sun = Color(red: 1.0, green: 0.78, blue: 0.29)

    static let brand = LinearGradient(colors: [coral, pink], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let corner: CGFloat = 22

    /// 画面の背景（上に淡い色）
    static func background(_ scheme: ColorScheme) -> LinearGradient {
        let top = scheme == .dark ? Color(red: 0.20, green: 0.10, blue: 0.13) : Color(red: 1.0, green: 0.93, blue: 0.90)
        let bottom = scheme == .dark ? Color(red: 0.06, green: 0.06, blue: 0.08) : Color(red: 0.98, green: 0.97, blue: 0.97)
        return LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .center)
    }
}

/// 白いカード
struct CardModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .fill(scheme == .dark ? Color(white: 0.13) : Color.white)
                    .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.06), radius: 12, y: 4)
            )
    }
}

extension View {
    func card() -> some View { modifier(CardModifier()) }
}

/// 押すと少し縮むボタン（主な操作）
struct BrandButtonStyle: ButtonStyle {
    var fill: AnyShapeStyle = AnyShapeStyle(Theme.brand)
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 15)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isEnabled ? fill : AnyShapeStyle(Color.gray.opacity(0.35)))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

/// 単語の札（並べ替え・聞き取り）
struct TileButtonStyle: ButtonStyle {
    var selected = false
    @Environment(\.colorScheme) private var scheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(selected ? Color.white : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? AnyShapeStyle(Theme.indigo) : AnyShapeStyle(scheme == .dark ? Color(white: 0.2) : Color.white))
                    .shadow(color: .black.opacity(0.08), radius: 0, y: configuration.isPressed ? 0 : 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(selected ? 0 : 0.12), lineWidth: 1)
            )
            .offset(y: configuration.isPressed ? 2 : 0)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}

/// 今日の目標の輪
struct GoalRing: View {
    let progress: Double
    var lineWidth: CGFloat = 10

    var body: some View {
        ZStack {
            Circle().stroke(Color.primary.opacity(0.08), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(progress, 0.001))
                .stroke(Theme.brand, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.6), value: progress)
        }
    }
}

/// 紙吹雪（ドリルの結果）
struct Confetti: View {
    @State private var fall = false
    private let pieces: [(x: CGFloat, delay: Double, color: Color, size: CGFloat)] = (0..<36).map { i in
        let colors = [Theme.coral, Theme.pink, Theme.sun, Theme.mint, Theme.indigo]
        return (x: CGFloat((i * 37) % 100) / 100, delay: Double(i % 9) * 0.07, color: colors[i % colors.count], size: CGFloat(6 + (i % 4) * 2))
    }

    var body: some View {
        GeometryReader { proxy in
            ForEach(0..<pieces.count, id: \.self) { i in
                let piece = pieces[i]
                RoundedRectangle(cornerRadius: 2)
                    .fill(piece.color)
                    .frame(width: piece.size, height: piece.size * 1.6)
                    .rotationEffect(.degrees(fall ? Double(i * 47) : 0))
                    .position(x: piece.x * proxy.size.width, y: fall ? proxy.size.height + 20 : -20)
                    .animation(.easeIn(duration: 1.8).delay(piece.delay), value: fall)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { fall = true }
    }
}
