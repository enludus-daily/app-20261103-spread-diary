import SwiftUI

/// 1 枚のカード：めくれる大きなカード、言い方の違い、単語、覚えた度合い、共有
struct PhraseDetailView: View {
    @Environment(PhraseStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let phraseID: UUID
    @State private var flipped = false
    @State private var drillRequest: DrillRequest?
    @State private var shareRequest: Phrase?
    @State private var confirmDelete = false

    var body: some View {
        if let phrase = store.phrase(id: phraseID) {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    FlipCard(flipped: flipped) {
                        CardFace(scene: phrase.sceneKind) {
                            VStack(alignment: .leading) {
                                Label(phrase.sceneKind.title, systemImage: phrase.sceneKind.symbol)
                                    .font(Typo.label(.caption))
                                    .foregroundStyle(phrase.sceneKind.swatch.deep)
                                Spacer(minLength: 0)
                                Text(phrase.japanese).font(.title3.weight(.semibold)).foregroundStyle(Ink.text)
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } back: {
                        CardFace(scene: phrase.sceneKind) {
                            HStack {
                                MarkedText(text: phrase.english, font: Typo.english(.title3))
                                Spacer(minLength: 0)
                                SpeakButton(text: phrase.english)
                            }
                            .frame(maxHeight: .infinity)
                        }
                    }
                    .frame(height: 210)
                    .onTapGesture { flipped.toggle() }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("ダブルタップでめくります")

                    if !phrase.variants.isEmpty {
                        SectionMark(title: "言い方の違い", color: phrase.sceneKind.swatch.accent)
                        ForEach(phrase.variants) { variant in
                            VariantLine(label: variant.label, text: variant.english, scene: phrase.sceneKind)
                        }
                    }
                    if !phrase.words.isEmpty {
                        SectionMark(title: "単語カード", color: phrase.sceneKind.swatch.accent)
                        ForEach(phrase.words) { word in
                            HStack {
                                Text(word.english).font(Typo.english(.body)).foregroundStyle(Ink.text)
                                Spacer()
                                Text(word.japanese.isEmpty ? "（意味はまだ）" : word.japanese)
                                    .font(.callout)
                                    .foregroundStyle(Ink.sub)
                            }
                        }
                    }
                    SectionMark(title: "覚えた度合い", color: Ink.marker)
                    HStack(spacing: 4) {
                        ForEach(0..<ReviewState.maxBox, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(i < phrase.review.box ? MarkerLevel.color(min(i / 2 + 1, 4)) : Ink.rule)
                                .frame(height: 14)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("覚えた度合い \(phrase.review.box) / \(ReviewState.maxBox)")
                    Text(reviewText(phrase.review))
                        .font(.callout)
                        .foregroundStyle(Ink.sub)
                    Button {
                        drillRequest = DrillRequest(ids: [phrase.id])
                    } label: {
                        Label("このカードを練習する", systemImage: "play.fill")
                    }
                    .buttonStyle(InkButtonStyle())
                    Button {
                        shareRequest = phrase
                    } label: {
                        Label("カードの画像で共有", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(OutlineButtonStyle())
                }
                .padding(.leading, 52)
                .padding(.trailing, Space.xl)
                .padding(.vertical, Space.xl)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(RuledPaper())
            .navigationTitle("カード")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("リングから外す")
                }
            }
            .confirmationDialog("このカードをリングから外しますか？", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("外す", role: .destructive) {
                    store.delete(ids: [phrase.id])
                    dismiss()
                }
            } message: {
                Text("覚えた度合いの記録も消えます。束のカードなら、あとでまた通せます。")
            }
            .fullScreenCover(item: $drillRequest) { request in
                DrillView(phraseIDs: request.ids)
            }
            .sheet(item: $shareRequest) { phrase in
                ShareCardSheet(phrase: phrase)
            }
        } else {
            ContentUnavailableView("カードが見つかりません", systemImage: "rectangle.portrait.slash",
                                   description: Text("リングから外したカードです。「カード」の束から、また通せます。"))
        }
    }

    private func reviewText(_ review: ReviewState) -> String {
        if review.isMastered { return "覚えました（正解 \(review.correctCount) 回）" }
        let next = review.due <= .now ? "今日" : review.due.formatted(.dateTime.month().day())
        return "次の復習：\(next)　正解 \(review.correctCount) 回・まだ \(review.wrongCount) 回"
    }
}
