import SwiftUI

/// 作った英語を確かめて、直してから保存する
struct DraftSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: PhraseDraft
    let notice: String?
    let onSave: (PhraseDraft) -> Void

    init(draft: PhraseDraft, notice: String?, onSave: @escaping (PhraseDraft) -> Void) {
        _draft = State(initialValue: draft)
        self.notice = notice
        self.onSave = onSave
    }

    private var canSave: Bool {
        !draft.english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 文の中で、まだカードにしていない単語
    private var candidateWords: [String] {
        let existing = Set(draft.words.map { $0.english.lowercased() })
        var seen: Set<String> = []
        return Tokenizer.tokens(draft.english)
            .map(Tokenizer.core)
            .filter { word in
                let key = word.lowercased()
                return word.count >= 2 && !existing.contains(key) && seen.insert(key).inserted
            }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let notice {
                    Section {
                        Label(notice, systemImage: "info.circle")
                            .font(.callout)
                    }
                }
                Section("日本語") {
                    Text(draft.japanese)
                }
                Section {
                    HStack(alignment: .top) {
                        TextField("英語を書く", text: $draft.english, axis: .vertical)
                            .font(.title3.weight(.semibold))
                            .lineLimit(1...6)
                            .textInputAutocapitalization(.sentences)
                        if canSave {
                            SpeakButton(text: draft.english)
                        }
                    }
                } header: {
                    Text("英語（直せます）")
                } footer: {
                    Text("作った: \(draft.source.label)。提案なので、誤ることがあります。")
                }
                if !draft.variants.isEmpty {
                    Section("言い方の違い") {
                        ForEach(draft.variants) { variant in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Chip(text: variant.label, color: .purple)
                                    Text(variant.english)
                                }
                                Spacer()
                                SpeakButton(text: variant.english)
                            }
                        }
                    }
                }
                Section {
                    ForEach($draft.words) { $word in
                        HStack {
                            Text(word.english)
                                .font(.body.weight(.semibold))
                            Spacer()
                            TextField("意味（日本語）", text: $word.japanese)
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { draft.words.remove(atOffsets: $0) }
                    if draft.words.count < Phrase.maxWords, !candidateWords.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("文の単語をタップしてカードに足す")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            WordFlowLayout(spacing: 6, lineSpacing: 6) {
                                ForEach(candidateWords, id: \.self) { word in
                                    Button(word) {
                                        draft.words.append(VocabItem(english: word, japanese: ""))
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }
                    }
                } header: {
                    Text("単語カード（\(draft.words.count)/\(Phrase.maxWords)）")
                }
            }
            .navigationTitle("ドリルに入れる")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("やめる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}
