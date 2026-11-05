import SwiftUI

/// 単語を左から並べ、幅が足りなければ折り返す
struct WordFlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let width = min(size.width, maxWidth)
            if x > 0, x + width > maxWidth {
                y += lineHeight + lineSpacing
                x = 0
                lineHeight = 0
            }
            x += width + spacing
            widest = max(widest, x - spacing)
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: proposal.width ?? widest, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let width = min(size.width, maxWidth)
            if x > 0, x + width > maxWidth {
                y += lineHeight + lineSpacing
                x = 0
                lineHeight = 0
            }
            subview.place(
                at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                proposal: ProposedViewSize(width: width, height: size.height)
            )
            x += width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

/// 読み上げボタン
struct SpeakButton: View {
    let text: String

    var body: some View {
        Button {
            Speaker.shared.speak(text)
        } label: {
            Image(systemName: "speaker.wave.2.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(Ink.pen)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Ink.card).overlay(Circle().strokeBorder(Ink.rule, lineWidth: 1)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("英語を読み上げる")
    }
}

extension Phrase.Source {
    var label: String {
        switch self {
        case .model: "Apple Intelligence"
        case .translation: "Apple の翻訳"
        case .manual: "手入力"
        case .bank: "場面の束"
        }
    }
}
