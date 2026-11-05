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
                context.stroke(line, with: .color(Ink.rule), lineWidth: 0.6)
                y += lineSpacing
            }
            if showsMargin {
                var margin = Path()
                margin.move(to: CGPoint(x: marginX, y: 0))
                margin.addLine(to: CGPoint(x: marginX, y: size.height))
                context.stroke(margin, with: .color(Ink.margin), lineWidth: 0.8)
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
                .font(Typo.heading(.largeTitle))
                .kerning(-0.5)
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
    /// 前の版の色の指定（いまはテーマ色 1 系統なので使わない）
    var color: Color = .clear

    var body: some View {
        HStack(spacing: Space.s) {
            Text(title)
                .font(Typo.heading(.title3))
                .foregroundStyle(Ink.text)
            Rectangle().fill(Tone.current.swatch.accent).frame(height: 0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(.isHeader)
    }
}

/// 付箋（ちょっとした一文・案内）。少し傾ける
struct StickyNote<Content: View>: View {
    var color: Color = Tone.current.swatch.paper
    /// 前の版の傾け（いまは使わない：飾りは主役の 1 か所と共有カードだけ）
    var tilt: Double = 0
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) { content }
            .padding(Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(Ink.text)
            .background(RoundedRectangle(cornerRadius: Radius.control, style: .continuous).fill(color))
            .overlay(RoundedRectangle(cornerRadius: Radius.control, style: .continuous).strokeBorder(Ink.rule, lineWidth: 0.8))
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
