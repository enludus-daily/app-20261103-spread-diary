import SwiftUI

/// 見開き。左のページ＝自分の英文、右のページ＝直した英文と説明。
/// iPhone Duo の内側の画面（horizontal size class が regular）では左右に並べ、
/// 外側の画面・ほかの iPhone（compact）では上下に重ねる。
/// 機種・向き・画面の大きさでは決めない（Apple Tech Talk「Prepare your app for iPhone Duo」）。
struct SpreadView: View {
    @Environment(DiaryStore.self) private var store
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let entryID: UUID
    let corrector: any SentenceCorrector

    @State private var isCorrecting = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let entry = store.entry(id: entryID) {
                if horizontalSizeClass == .regular {
                    HStack(alignment: .top, spacing: 0) {
                        ScrollView { leftPage(entry).padding() }
                            .frame(maxWidth: .infinity)
                        Divider()
                        ScrollView { rightPage(entry).padding() }
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            leftPage(entry)
                            rightPage(entry)
                        }
                        .padding()
                    }
                }
            } else {
                ContentUnavailableView("日記が見つかりません", systemImage: "book.closed")
            }
        }
        .navigationTitle(store.entry(id: entryID)?.date.formatted(date: .abbreviated, time: .omitted) ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .alert("直せませんでした", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - 左のページ

    private func leftPage(_ entry: DiaryEntry) -> some View {
        Page(title: "自分の英文", systemImage: "pencil") {
            Text("英語で 1〜3 文。間違いを気にせず書きます。")
                .font(.footnote)
                .foregroundStyle(.secondary)
            TextEditor(text: Binding(
                get: { store.entry(id: entryID)?.original ?? "" },
                set: { store.setOriginal($0, id: entryID) }
            ))
            .font(.body)
            .frame(minHeight: 160)
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(.background, in: RoundedRectangle(cornerRadius: 10))
            .textInputAutocapitalization(.sentences)
            .accessibilityLabel("自分の英文")
            Text("\(entry.original.count) / \(DiaryEntry.maxLength) 文字")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    // MARK: - 右のページ

    private func rightPage(_ entry: DiaryEntry) -> some View {
        Page(title: "直した英文", systemImage: "checkmark.seal") {
            switch corrector.status {
            case .available:
                Button {
                    Task { await correct() }
                } label: {
                    if isCorrecting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Apple Intelligence で直す", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCorrecting || !entry.hasOriginal)
                Text("端末の中で直します（通信しません）。提案なので、誤ることがあります。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .unavailable(let reason):
                Label(reason, systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            TextEditor(text: Binding(
                get: { store.entry(id: entryID)?.corrected ?? "" },
                set: { store.setCorrectedManually($0, id: entryID) }
            ))
            .font(.body)
            .frame(minHeight: 120)
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(.background, in: RoundedRectangle(cornerRadius: 10))
            .textInputAutocapitalization(.sentences)
            .accessibilityLabel("直した英文")

            if entry.hasOriginal, entry.hasCorrection {
                DiffSection(parts: WordDiff.compare(entry.original, entry.corrected))
            }

            if !entry.note.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.source == .model ? "説明（Apple Intelligence の提案）" : "説明")
                        .font(.subheadline.weight(.semibold))
                    Text(entry.note)
                        .font(.callout)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func correct() async {
        isCorrecting = true
        defer { isCorrecting = false }
        do {
            try await store.requestCorrection(id: entryID, using: corrector)
        } catch CorrectionError.emptyInput {
            errorMessage = "左のページに英文を書いてください。"
        } catch {
            errorMessage = "うまく直せませんでした。文を短くするか、少し書き換えてもう一度試してください。右のページに自分で書くこともできます。"
        }
    }
}

/// 1 ページ分の枠
private struct Page<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.title3.weight(.semibold))
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 16))
    }
}

/// 変わった所（消えた単語は取り消し線、増えた単語は太字）
private struct DiffSection: View {
    let parts: [WordDiff.Part]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            WordFlowLayout(spacing: 5, lineSpacing: 6) {
                ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                    word(part)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var title: String {
        let changes = WordDiff.changeCount(parts)
        return changes == 0 ? "変わった所はありません" : "変わった所（\(changes) 語）"
    }

    @ViewBuilder
    private func word(_ part: WordDiff.Part) -> some View {
        switch part.kind {
        case .same:
            Text(part.text)
        case .removed:
            Text(part.text)
                .strikethrough(true, color: .red)
                .foregroundStyle(.red)
        case .added:
            Text(part.text)
                .bold()
                .foregroundStyle(.green)
                .padding(.horizontal, 2)
                .background(Color.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
        }
    }

    private var accessibilityText: String {
        parts.compactMap { part -> String? in
            switch part.kind {
            case .same: return nil
            case .removed: return "消した \(part.text)"
            case .added: return "足した \(part.text)"
            }
        }
        .joined(separator: "、")
    }
}

/// 単語を左から並べ、幅が足りなければ折り返す
struct WordFlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

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
