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

/// 金属のリング：カードの上へ出た所と、穴の中に見える所だけを描く（カードの紙の裏に回る所は隠す）
struct RingMetal: View {
    /// 穴の中心から上へ出る高さ
    var radius: CGFloat = 21
    /// 単独で置くとき（束の絵など）は全部描く
    var throughHole = true

    var body: some View {
        let hole = CardShape.holeInset + CardShape.holeSize / 2
        Canvas { context, size in
            // カードの左上を (0, top) とした座標。リングの下端が穴の中心を通る
            let top = radius * 2
            let center = CGPoint(x: hole, y: top + hole - radius)
            let ring = Path(ellipseIn: CGRect(x: center.x - radius * 0.7, y: center.y - radius, width: radius * 1.4, height: radius * 2))
            var c = context
            if throughHole {
                var visible = Path(CGRect(x: 0, y: 0, width: size.width, height: top))
                visible.addEllipse(in: CGRect(x: CardShape.holeInset, y: top + CardShape.holeInset,
                                              width: CardShape.holeSize, height: CardShape.holeSize))
                c.clip(to: visible)
            }
            c.stroke(ring, with: .color(Ink.ring), lineWidth: 4.6)
            var shine = Path()
            shine.addArc(center: center, radius: radius * 0.8, startAngle: .degrees(205), endAngle: .degrees(250), clockwise: false)
            c.stroke(shine, with: .color(Ink.ringShine), lineWidth: 1.2)
        }
        .frame(width: hole * 2 + 4, height: radius * 2 + hole + 8)
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
                    .offset(y: -42)
                    .allowsHitTesting(false)
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
