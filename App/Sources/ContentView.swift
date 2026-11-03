import SwiftUI

/// 日記の一覧。行を開くと見開き（SpreadView）になる。
struct ContentView: View {
    @Environment(DiaryStore.self) private var store
    let corrector: any SentenceCorrector
    @State private var path: [UUID] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    StreakHeader(days: store.streak())
                    Button {
                        path.append(store.addEntry())
                    } label: {
                        Label("今日の英文を書く", systemImage: "square.and.pencil")
                            .font(.headline)
                    }
                }
                Section("日記") {
                    ForEach(store.sortedEntries) { entry in
                        NavigationLink(value: entry.id) {
                            EntryRow(entry: entry)
                        }
                    }
                    .onDelete { offsets in
                        let sorted = store.sortedEntries
                        store.delete(ids: offsets.map { sorted[$0].id })
                    }
                }
            }
            .overlay {
                if store.entries.isEmpty {
                    ContentUnavailableView(
                        "まだ日記がありません",
                        systemImage: "book",
                        description: Text("「今日の英文を書く」から、英語で 1〜3 文書いてみましょう。")
                    )
                }
            }
            .navigationTitle("見開き英日記")
            .navigationDestination(for: UUID.self) { id in
                SpreadView(entryID: id, corrector: corrector)
            }
        }
    }
}

private struct StreakHeader: View {
    let days: Int

    private var title: String {
        days > 0 ? "\(days) 日続けて書いています" : "今日から始めましょう"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "flame")
                .font(.title2)
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text("英語で書いて、直した文と見開きで比べる")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct EntryRow: View {
    let entry: DiaryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.weight(.semibold))
                if entry.isSample {
                    Tag(text: "見本", color: .purple)
                }
                if entry.hasCorrection {
                    Tag(text: "直し済み", color: .green)
                }
            }
            Text(entry.hasOriginal ? entry.original : "（まだ書いていません）")
                .font(.body)
                .foregroundStyle(entry.hasOriginal ? Color.primary : Color.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
    }
}

private struct Tag: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

#Preview {
    ContentView(corrector: UnavailableCorrector(reason: "プレビュー"))
        .environment(DiaryStore(defaults: UserDefaults(suiteName: "preview")!))
}
