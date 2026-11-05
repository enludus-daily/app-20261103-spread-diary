import SwiftUI

/// 共有カード：罫線のノートにリングのカードを貼った絵（360×640 を 3 倍 → 1080×1920）
struct ShareCardArt: View {
    let phrase: Phrase

    var body: some View {
        ZStack {
            RuledPaper(lineSpacing: 24, marginX: 30)
            VStack(alignment: .leading, spacing: 18) {
                Text("言えるようになった英語")
                    .font(.system(size: 13, weight: .medium))
                    .kerning(0.6)
                    .foregroundStyle(Ink.sub)
                CardFace(scene: phrase.sceneKind) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(phrase.japanese)
                            .font(.system(size: 13))
                            .foregroundStyle(Ink.sub)
                        Spacer(minLength: 0)
                        Text(phrase.english)
                            .font(.system(size: 24, weight: .semibold, design: .serif))
                            .foregroundStyle(Ink.text)
                            .padding(.horizontal, 4)
                            .background(RoundedRectangle(cornerRadius: 3).fill(Ink.marker.opacity(0.75)))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 250)
                .rotationEffect(.degrees(-3))
                HStack {
                    Spacer()
                    Hanko(text: "言", size: 70).rotationEffect(.degrees(-10))
                }
                Spacer()
                HStack(spacing: 6) {
                    Text("言いたい英語ドリル")
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                    Text("· \(phrase.sceneKind.title)")
                        .font(.system(size: 12))
                }
                .foregroundStyle(Ink.text)
            }
            .padding(.leading, 46)
            .padding(.trailing, 28)
            .padding(.vertical, 40)
        }
        .frame(width: 360, height: 640)
    }
}

/// 共有の画面：絵を見せて、ShareLink で渡す（作るのは端末の中だけ）
struct ShareCardSheet: View {
    let phrase: Phrase
    @Environment(\.dismiss) private var dismiss
    @State private var image: Image?
    @State private var failed = false

    var body: some View {
        NavigationStack {
            VStack(spacing: Space.xl) {
                ShareCardArt(phrase: phrase)
                    .environment(\.colorScheme, .light)
                    .scaleEffect(0.8)
                    .frame(width: 288, height: 512)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.panel, style: .continuous))
                    .liftShadow()
                if let image {
                    ShareLink(item: image, preview: SharePreview(phrase.english, image: image)) {
                        Label("画像を共有する", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(InkButtonStyle())
                } else if failed {
                    Text("画像を作れませんでした。もう一度開き直してください。")
                        .font(.callout)
                        .foregroundStyle(Ink.redPen)
                } else {
                    ProgressView("画像を作っています")
                }
            }
            .padding(Space.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RuledPaper(showsMargin: false))
            .navigationTitle("共有カード")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("とじる") { dismiss() } }
            }
            .onAppear(perform: render)
        }
    }

    private func render() {
        let renderer = ImageRenderer(content: ShareCardArt(phrase: phrase).environment(\.colorScheme, .light))
        renderer.scale = 3
        if let uiImage = renderer.uiImage {
            image = Image(uiImage: uiImage)
        } else {
            failed = true
        }
    }
}
