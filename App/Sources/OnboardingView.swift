import SwiftUI

/// 最初の 10 秒：3 ページ。どのページも動く見本（動きを減らす設定では止まった絵）
struct OnboardingView: View {
    let onDone: () -> Void
    @State private var page = 0

    var body: some View {
        ZStack {
            RuledPaper()
            VStack(spacing: Space.xl) {
                TabView(selection: $page) {
                    OnboardingPage(
                        title: "言いたいことが、\nリングの単語カードになる",
                        text: "職場・旅行・日常・気持ち・お店・人づきあい。\(PhraseBank.shared.phrases.count) 枚の英語フレーズを、毎日 3 枚ずつめくります。"
                    ) { FlipDemo() }
                        .tag(0)
                    OnboardingPage(
                        title: "赤シートをずらして、\n思い出す",
                        text: "日本語を見て、英語で言ってから、赤シートを下へ。言えたら ◎、まだなら ×。"
                    ) { SheetDemo() }
                        .tag(1)
                    OnboardingPage(
                        title: "忘れかけたころに、\nまた出てくる",
                        text: "できたカードは 1・2・4・7・15・30 日後に。書いた内容と記録は、この iPhone の中だけに残ります。"
                    ) { BoxDemo() }
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                HStack(spacing: Space.s) {
                    ForEach(0..<3, id: \.self) { i in
                        Capsule().fill(i == page ? Ink.pen : Ink.rule).frame(width: i == page ? 24 : 8, height: 8)
                    }
                }
                .animation(.snappy, value: page)
                .accessibilityHidden(true)
                Button {
                    if page < 2 { withAnimation { page += 1 } } else { onDone() }
                } label: {
                    Text(verbatim: page < 2 ? "次へ" : "はじめる（今日の 3 枚へ）")
                }
                .buttonStyle(InkButtonStyle())
                .frame(maxWidth: 420)
                Button("とばす", action: onDone)
                    .font(.subheadline)
                    .foregroundStyle(Ink.sub)
                    .frame(minHeight: 44)
            }
            .padding(Space.xl)
        }
    }
}

private struct OnboardingPage<Demo: View>: View {
    let title: String
    let text: String
    @ViewBuilder let demo: Demo

    var body: some View {
        VStack(spacing: Space.xl) {
            Spacer(minLength: 0)
            demo.frame(height: 220)
            Text(title)
                .font(Typo.heading(.title2))
                .foregroundStyle(Ink.text)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(text)
                .font(.callout)
                .foregroundStyle(Ink.sub)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 420)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Space.l)
    }
}

/// 見本 1：カードが 1.6 秒ごとにめくれる
private struct FlipDemo: View {
    @State private var flipped = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        FlipCard(flipped: flipped) {
            CardFace(scene: .travel) {
                VStack(alignment: .leading) {
                    Label("旅行", systemImage: "airplane").font(Typo.label(.caption)).foregroundStyle(SceneKind.travel.swatch.deep)
                    Spacer(minLength: 0)
                    Text("駅までの道を教えてもらえますか？").font(.title3.weight(.bold)).foregroundStyle(Ink.text)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } back: {
            CardFace(scene: .travel) {
                MarkedText(text: "Could you tell me the way to the station?", font: Typo.english(.title3))
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: 300, height: 190)
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(1600))
                flipped.toggle()
            }
        }
        .accessibilityLabel("見本：駅までの道を教えてもらえますか？ のカード。めくると Could you tell me the way to the station?")
    }
}

/// 見本 2：赤シートが下へずれて、緑のマーカーの英語が見える
private struct SheetDemo: View {
    @State private var down = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        CardFace(scene: .work) {
            VStack(alignment: .leading, spacing: Space.m) {
                Text("今日は少し早めに帰ります。").font(.footnote).foregroundStyle(Ink.sub)
                ZStack(alignment: .top) {
                    MarkedText(text: "I'm going to leave a little early today.", font: Typo.english(.title3))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    GeometryReader { proxy in
                        Rectangle()
                            .fill(Ink.redSheet.opacity(0.95))
                            .blendMode(.multiply)
                            .frame(height: proxy.size.height + 20)
                            .offset(y: down ? proxy.size.height * 0.85 : 0)
                    }
                    .clipped()
                }
                .compositingGroup()
            }
            .frame(maxHeight: .infinity)
        }
        .frame(width: 300, height: 190)
        .task {
            guard !reduceMotion else { down = true; return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(1250))
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { down.toggle() }
            }
        }
        .accessibilityLabel("見本：赤シートをずらすと、英語の答えが見えます")
    }
}

/// 見本 3：カード箱の仕切りを、カードが右へ進む
private struct BoxDemo: View {
    @State private var step = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let days = ["今日", "1日", "2日", "4日", "7日", "15日", "30日"]

    var body: some View {
        VStack(spacing: Space.m) {
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(0..<7, id: \.self) { box in
                    VStack(spacing: Space.xs) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: Radius.card).fill(Ink.card).frame(width: 34, height: 70)
                                .overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Ink.rule))
                            if box == step {
                                RoundedRectangle(cornerRadius: Radius.card)
                                    .fill(SceneKind.feelings.swatch.accent)
                                    .frame(width: 28, height: 50)
                                    .padding(.bottom, 4)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        Text(days[box]).font(Typo.label(.caption2)).foregroundStyle(Ink.sub)
                    }
                }
            }
            Text(verbatim: step == 6 ? "覚えた！" : "できたら右へ")
                .font(Typo.heading(.headline))
                .foregroundStyle(step == 6 ? Ink.redPen : Ink.text)
        }
        .task {
            guard !reduceMotion else { step = 3; return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(900))
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { step = (step + 1) % 7 }
            }
        }
        .accessibilityLabel("見本：できたカードは、1・2・4・7・15・30 日後にまた出てきます")
    }
}
