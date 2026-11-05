import SwiftUI

/// 罫線のノート（背景）：青い罫 28pt 間隔・赤い余白の線。上の数行は見出しの欄で罫を薄くする
struct RuledPaper: View {
    var lineSpacing: CGFloat = 28
    var marginX: CGFloat = 36
    var showsMargin = true

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Ink.paper))
            var y: CGFloat = lineSpacing * 3
            while y < size.height {
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(line, with: .color(Ink.rule), lineWidth: 0.8)
                y += lineSpacing
            }
            if showsMargin {
                var margin = Path()
                margin.move(to: CGPoint(x: marginX, y: 0))
                margin.addLine(to: CGPoint(x: marginX, y: size.height))
                context.stroke(margin, with: .color(Ink.margin), lineWidth: 1)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// ノートのページ見出し：セリフ体の見出し＋日付のスタンプ風の小さな字
struct PageHeading: View {
    let title: String
    var caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            if let caption {
                Text(caption)
                    .font(Typo.label(.caption))
                    .kerning(0.6)
                    .foregroundStyle(Ink.sub)
            }
            Text(title)
                .font(Typo.heading(.title))
                .foregroundStyle(Ink.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// ノートの区切り（小見出し）：セリフの小見出し＋下にマーカーを引く
struct SectionMark: View {
    let title: String
    var color: Color = Ink.marker

    var body: some View {
        Text(title)
            .font(Typo.heading(.headline))
            .foregroundStyle(Ink.text)
            .padding(.horizontal, 2)
            .background(alignment: .bottom) {
                Capsule().fill(color.opacity(0.45)).frame(height: 8).offset(y: -2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// 付箋（ちょっとした一文・案内）。少し傾ける
struct StickyNote<Content: View>: View {
    var color: Color = SceneKind.daily.swatch.soft
    var tilt: Double = -1.5
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) { content }
            .padding(Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Rectangle().fill(color))
            .overlay(alignment: .top) {
                Rectangle().fill(.black.opacity(0.05)).frame(height: 10)
            }
            .rotationEffect(.degrees(tilt))
            .paperShadow()
    }
}

/// マスキングテープ：両端ギザギザ（歯 4・深さ最大 3pt）
struct TapeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let teeth = 4
        let depth: CGFloat = 3
        let step = rect.height / CGFloat(teeth)
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        for i in 0..<teeth {
            p.addLine(to: CGPoint(x: rect.maxX - depth, y: rect.minY + step * (CGFloat(i) + 0.5)))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + step * CGFloat(i + 1)))
        }
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        for i in (0..<teeth).reversed() {
            p.addLine(to: CGPoint(x: rect.minX + depth, y: rect.minY + step * (CGFloat(i) + 0.5)))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + step * CGFloat(i)))
        }
        p.closeSubpath()
        return p
    }
}
