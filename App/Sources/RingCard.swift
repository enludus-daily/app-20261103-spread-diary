import SwiftUI

/// 単語カードの形：角丸 6、左上にリングを通す穴（even-odd で抜く）
struct CardShape: Shape {
    static let holeInset: CGFloat = 14
    static let holeSize: CGFloat = 13

    func path(in rect: CGRect) -> Path {
        var p = Path(roundedRect: rect, cornerRadius: Radius.card, style: .continuous)
        p.addEllipse(in: CGRect(x: rect.minX + Self.holeInset, y: rect.minY + Self.holeInset, width: Self.holeSize, height: Self.holeSize))
        return p
    }
}

/// 金属のリング（穴に通っている所だけ見える）
struct RingMetal: View {
    var size: CGFloat = 34

    var body: some View {
        Canvas { context, canvas in
            let rect = CGRect(x: 2, y: 2, width: canvas.width - 4, height: canvas.height - 4)
            let ring = Path(ellipseIn: rect)
            context.stroke(ring, with: .color(Ink.ring), lineWidth: 3.2)
            var shine = Path()
            shine.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: rect.width / 2,
                         startAngle: .degrees(200), endAngle: .degrees(260), clockwise: false)
            context.stroke(shine, with: .color(Ink.ringShine), lineWidth: 1.2)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// リング綴じの単語カード（片面）。場面の色の紙に罫を 1 本、左上に穴とリング
struct CardFace<Content: View>: View {
    let scene: SceneKind
    var showsRing = true
    var ruled = true
    @ViewBuilder let content: Content

    var body: some View {
        let swatch = scene.swatch
        ZStack(alignment: .topLeading) {
            CardShape()
                .fill(swatch.soft, style: FillStyle(eoFill: true))
                .paperShadow()
            if ruled {
                GeometryReader { proxy in
                    Path { p in
                        let y = proxy.size.height - 30
                        p.move(to: CGPoint(x: 18, y: y))
                        p.addLine(to: CGPoint(x: proxy.size.width - 18, y: y))
                    }
                    .stroke(swatch.accent.opacity(0.45), lineWidth: 1)
                }
                .allowsHitTesting(false)
            }
            content
                .padding(.top, 34)
                .padding(.horizontal, Space.xl)
                .padding(.bottom, Space.xl)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if showsRing {
                RingMetal()
                    .offset(x: CardShape.holeInset + CardShape.holeSize / 2 - 17, y: -12)
            }
        }
    }
}

/// めくれる単語カード：260ms・easeInOut、Y 軸で回し、半分で面を入れ替える。途中で 1.18 倍に浮かせる
/// （五十音マインスイーパーのめくり BoardTile.tsx の値。動きを減らす設定では、面を直接入れ替える）
struct FlipCard<Front: View, Back: View>: View {
    var flipped: Bool
    @ViewBuilder let front: Front
    @ViewBuilder let back: Back
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            ZStack {
                if flipped { back } else { front }
            }
        } else {
            ZStack {
                FlipSide(isBack: false) { front }
                FlipSide(isBack: true) { back }
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            }
            .modifier(FlipEffect(angle: flipped ? 180 : 0))
            .animation(.easeInOut(duration: 0.26), value: flipped)
        }
    }
}

/// めくりの角度から、見える面と浮き上がりを決める
struct FlipEffect: ViewModifier, Animatable {
    var angle: Double

    nonisolated var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func body(content: Content) -> some View {
        content
            .environment(\.flipShowsBack, angle >= 90)
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .scaleEffect(1 + 0.18 * sin(angle * .pi / 180))
            .shadow(color: .black.opacity(0.12 * sin(angle * .pi / 180)), radius: 12, y: 10)
    }
}

private struct FlipShowsBackKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var flipShowsBack: Bool {
        get { self[FlipShowsBackKey.self] }
        set { self[FlipShowsBackKey.self] = newValue }
    }
}

/// FlipCard の面：めくりの半分で表と裏を入れ替えるため、自分が見えてよいかを環境から読む
struct FlipSide<Content: View>: View {
    let isBack: Bool
    @ViewBuilder let content: Content
    @Environment(\.flipShowsBack) private var showsBack

    var body: some View {
        content.opacity(showsBack == isBack ? 1 : 0)
    }
}
