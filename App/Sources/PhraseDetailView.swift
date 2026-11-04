import SwiftUI

/// フレーズの中身：英語・言い方の違い・単語・覚えた度合い
struct PhraseDetailView: View {
    @Environment(PhraseStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    let phraseID: UUID
    let onPractice: () -> Void

    var body: some View {
        if let phrase = store.phrase(id: phraseID) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    card {
                        Text(phrase.japanese)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline) {
                            Text(phrase.english)
                                .font(.title2.weight(.bold))
                                .textSelection(.enabled)
                            Spacer()
                            SpeakButton(text: phrase.english)
                                .font(.title3)
                        }
                        Chip(text: phrase.source.label, color: Theme.indigo)
                    }
                    if !phrase.variants.isEmpty {
                        card {
                            Text("言い方の違い").font(.headline)
                            ForEach(phrase.variants) { variant in
                                HStack(alignment: .top) {
                                    Chip(text: variant.label, color: .purple)
                                    Text(variant.english)
                                        .textSelection(.enabled)
                                    Spacer()
                                    SpeakButton(text: variant.english)
                                }
                            }
                        }
                    }
                    if !phrase.words.isEmpty {
                        card {
                            Text("単語カード").font(.headline)
                            ForEach(phrase.words) { word in
                                HStack {
                                    Text(word.english).font(.body.weight(.semibold))
                                    Spacer()
                                    Text(word.japanese.isEmpty ? "—" : word.japanese)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    card {
                        Text("覚えた度合い").font(.headline)
                        ProgressView(value: Double(phrase.review.box), total: Double(ReviewState.maxBox))
                            .tint(Theme.pink)
                        Text(reviewText(phrase.review))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Button(action: onPractice) {
                        Label("このフレーズを練習する", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(BrandButtonStyle())
                }
                .padding()
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background(scheme).ignoresSafeArea())
            .navigationTitle("フレーズ")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func reviewText(_ review: ReviewState) -> String {
        if review.isMastered {
            return "覚えました（正解 \(review.correctCount) 回）"
        }
        let next = review.due <= .now ? "今日" : review.due.formatted(date: .abbreviated, time: .omitted)
        return "次の復習: \(next)　正解 \(review.correctCount) 回・まだ \(review.wrongCount) 回"
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .card()
    }
}
