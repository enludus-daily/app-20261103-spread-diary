import SwiftUI
import UIKit

/// せってい：ノートのページに、カード・音と振動・おしらせ・使い方・プライバシー
struct SettingsView: View {
    let reminder: Reminder
    @AppStorage("settings.dailyCards") private var dailyCards = 3
    @AppStorage("settings.scenes") private var scenesCSV = ""
    @AppStorage("settings.haptics") private var haptics = true
    @AppStorage("settings.tone") private var tone = Tone.sky.rawValue
    @AppStorage("settings.speechRate") private var speechRate = 0.9
    @AppStorage("settings.reminder") private var reminderOn = false
    @AppStorage("settings.reminderHour") private var reminderHour = 20
    @AppStorage("onboarding.done") private var onboardingDone = true
    @Environment(\.openURL) private var openURL

    private var enabled: Set<String> {
        let picked = Set(scenesCSV.split(separator: ",").map(String.init))
        return picked.isEmpty ? Set(SceneKind.bankScenes.map(\.rawValue)) : picked
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    PageHeading(title: "せってい", caption: "言いたい英語ドリル")

                    SectionMark(title: "テーマ色")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: Space.m)], spacing: Space.m) {
                        ForEach(Tone.allCases) { option in
                            Button {
                                tone = option.rawValue
                            } label: {
                                VStack(spacing: Space.xs) {
                                    Circle()
                                        .fill(option.swatch.accent)
                                        .frame(width: 40, height: 40)
                                        .overlay(Circle().strokeBorder(option.swatch.deep, lineWidth: tone == option.rawValue ? 1.5 : 0))
                                        .padding(3)
                                        .overlay(Circle().strokeBorder(Ink.rule, lineWidth: 0.8))
                                    Text(option.title)
                                        .font(Typo.label(.caption2))
                                        .foregroundStyle(tone == option.rawValue ? Ink.text : Ink.sub)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                                .frame(minWidth: 44, minHeight: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(option.title)
                            .accessibilityAddTraits(tone == option.rawValue ? .isSelected : [])
                        }
                    }

                    SectionMark(title: "今日のカード")
                    row {
                        Stepper(value: $dailyCards, in: 1...5) {
                            Text("1 日に覚える枚数：\(dailyCards) 枚").foregroundStyle(Ink.text)
                        }
                    }
                    Text("今日のカードを選ぶ場面（どれも選ばないと、全部から選びます）")
                        .font(.footnote)
                        .foregroundStyle(Ink.sub)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: Space.s)], spacing: Space.s) {
                        ForEach(SceneKind.bankScenes) { scene in
                            let on = enabled.contains(scene.rawValue)
                            Button {
                                toggle(scene)
                            } label: {
                                Label(scene.title, systemImage: on ? "checkmark.square.fill" : "square")
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(TileButtonStyle(fill: on ? scene.swatch.soft : Ink.card, edge: on ? scene.swatch.accent : Ink.rule,
                                                         foreground: on ? scene.swatch.deep : Ink.sub))
                            .font(.subheadline.weight(.semibold))
                            .accessibilityValue(Text(verbatim: on ? "選んでいる" : "選んでいない"))
                        }
                    }

                    SectionMark(title: "音と振動", color: SceneKind.work.swatch.accent)
                    row { Toggle("振動", isOn: $haptics).foregroundStyle(Ink.text) }
                    row {
                        VStack(alignment: .leading, spacing: Space.s) {
                            Text("読み上げの速さ").foregroundStyle(Ink.text)
                            Slider(value: $speechRate, in: 0.5...1.2, step: 0.1) {
                                Text("読み上げの速さ")
                            } minimumValueLabel: {
                                Image(systemName: "tortoise")
                            } maximumValueLabel: {
                                Image(systemName: "hare")
                            }
                            Button("試しに聞く") { Speaker.shared.speak("Could you say that again?") }
                                .buttonStyle(OutlineButtonStyle())
                        }
                    }
                    Text("動きを減らす設定（アクセシビリティ）がオンなら、めくり・揺れ・紙吹雪を止めます。")
                        .font(.footnote)
                        .foregroundStyle(Ink.sub)

                    SectionMark(title: "おしらせ", color: SceneKind.travel.swatch.accent)
                    row {
                        VStack(alignment: .leading, spacing: Space.s) {
                            Toggle("毎日のおしらせ", isOn: Binding(get: { reminderOn && reminder.status != .denied }, set: { setReminder($0) }))
                                .foregroundStyle(Ink.text)
                                .disabled(reminder.status == .denied)
                            if reminderOn && reminder.status == .allowed {
                                Stepper(value: $reminderHour, in: 6...23) {
                                    Text("\(reminderHour) 時に「今日の 3 枚」").foregroundStyle(Ink.text)
                                }
                                .onChange(of: reminderHour) { _, hour in Reminder.schedule(hour: hour) }
                            }
                        }
                    }
                    if reminder.status == .denied {
                        StickyNote(color: SceneKind.feelings.swatch.soft) {
                            Text("通知が許可されていません").font(.headline)
                            Text("設定アプリの「通知」で、このアプリを許可すると、毎日のおしらせが届きます。").font(.callout)
                            Button("設定アプリを開く") {
                                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                            }
                            .buttonStyle(OutlineButtonStyle())
                        }
                    }

                    SectionMark(title: "使い方", color: SceneKind.social.swatch.accent)
                    Button {
                        onboardingDone = false
                    } label: {
                        Label("使い方をもう一度見る", systemImage: "book")
                    }
                    .buttonStyle(OutlineButtonStyle())

                    SectionMark(title: "プライバシー", color: Ink.marker)
                    StickyNote(color: SceneKind.travel.swatch.soft, tilt: 1) {
                        Text("書いた日本語・英語・練習の記録は、この iPhone の中だけに保存します。")
                        Text("英語を作るのは Apple Intelligence（端末の中のモデル）か Apple の翻訳（端末の中）で、アプリから外へは送りません。広告・解析もありません。")
                    }
                    .font(.callout)
                    .foregroundStyle(Ink.text)
                    Text("フレーズの束：\(PhraseBank.shared.phrases.count) 枚")
                        .font(Typo.label(.caption))
                        .foregroundStyle(Ink.sub)
                }
                .padding(.leading, 52)
                .padding(.trailing, Space.xl)
                .padding(.vertical, Space.xl)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(RuledPaper())
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { reminder.refresh() }
        }
    }

    private func row<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(Space.m)
            .background(RoundedRectangle(cornerRadius: Radius.control, style: .continuous).fill(Ink.card))
            .overlay(RoundedRectangle(cornerRadius: Radius.control, style: .continuous).strokeBorder(Ink.rule, lineWidth: 1))
    }

    private func toggle(_ scene: SceneKind) {
        var set = enabled
        if set.contains(scene.rawValue) { set.remove(scene.rawValue) } else { set.insert(scene.rawValue) }
        scenesCSV = set.count == SceneKind.bankScenes.count ? "" : set.sorted().joined(separator: ",")
    }

    private func setReminder(_ on: Bool) {
        reminderOn = on
        if on { reminder.enable(hour: reminderHour) } else { reminder.disable() }
    }
}
