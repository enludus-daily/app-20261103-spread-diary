import SwiftUI
import UIKit

// 見た目の決まり（.claude/skills/app-quality-bar/references/look.md §0〜4。トーンは StudyReel：淡い色・ほぼ白の地・セリフの見出し・細い線・弱い影）。
// 世界観：このアプリでは〔リング綴じの単語カード〕が〔フレーズ 1 つ〕になり、〔暗記用のシート〕が〔答えを隠して思い出す操作〕になる。
// アプリの色は 1 系統（利用者が 8 色から選ぶテーマ色）。場面はアイコン・小さな札の文字で分ける。グラデーションは使わない。

extension Color {
    /// ライトとダークで違う色（0xRRGGBB）
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    init(rgb: UInt32) {
        self.init(uiColor: UIColor(rgb: rgb))
    }
}

extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// 1 色の 5 段階（accent 主 明度 0.72〜0.86 / soft 淡い地 / deep 白文字のボタンと小さな文字だけ / paper 紙の地 / tape 飾り）
struct Swatch: Sendable {
    let accent: Color
    let soft: Color
    let deep: Color
    let paper: Color
    let tape: Color
}

/// テーマ色（StudyReel の 8 色。設定で選ぶ。既定は水色）
enum Tone: String, CaseIterable, Identifiable, Sendable {
    case sky, sakura, peach, mint, lavender, butter, milktea, matcha

    var id: String { rawValue }

    static var current: Tone {
        UserDefaults.standard.string(forKey: "settings.tone").flatMap(Tone.init(rawValue:)) ?? .sky
    }

    var title: String {
        switch self {
        case .sky: "水色"
        case .sakura: "さくら"
        case .peach: "ピーチ"
        case .mint: "ミント"
        case .lavender: "ラベンダー"
        case .butter: "バター"
        case .milktea: "ミルクティー"
        case .matcha: "抹茶"
        }
    }

    var swatch: Swatch {
        switch self {
        case .sky: Swatch(accent: Color(light: 0x9EC3E2, dark: 0x90B6D5), soft: Color(light: 0xE0ECF6, dark: 0x26313B),
                             deep: Color(light: 0x5E8DB8, dark: 0x4D799D), paper: Color(light: 0xF6F9FB, dark: 0x191C1F), tape: Color(light: 0xF2CBD0, dark: 0x4A3A3E))
        case .sakura: Swatch(accent: Color(light: 0xF1BFCB, dark: 0xD590A1), soft: Color(light: 0xF6DFE5, dark: 0x3B262B),
                             deep: Color(light: 0x964055, dark: 0x9D4D61), paper: Color(light: 0xFBF6F7, dark: 0x1F191A), tape: Color(light: 0xE1EDF6, dark: 0x34404B))
        case .peach: Swatch(accent: Color(light: 0xF4BBA4, dark: 0xD5A490), soft: Color(light: 0xF6E6DF, dark: 0x3B2C26),
                             deep: Color(light: 0x965940, dark: 0x9D644D), paper: Color(light: 0xFBF8F6, dark: 0x1F1B19), tape: Color(light: 0xF2CBD0, dark: 0x4A3A3E))
        case .mint: Swatch(accent: Color(light: 0xA8DCCB, dark: 0x92D3BE), soft: Color(light: 0xE2F3EE, dark: 0x263B34),
                             deep: Color(light: 0x40967A, dark: 0x4D9D83), paper: Color(light: 0xF6FBFA, dark: 0x191F1D), tape: Color(light: 0xF2CBD0, dark: 0x4A3A3E))
        case .lavender: Swatch(accent: Color(light: 0xC9BFEA, dark: 0xA090D5), soft: Color(light: 0xE5E0F5, dark: 0x2B263B),
                             deep: Color(light: 0x544096, dark: 0x604D9D), paper: Color(light: 0xF7F6FB, dark: 0x1A191F), tape: Color(light: 0xF2CBD0, dark: 0x4A3A3E))
        case .butter: Swatch(accent: Color(light: 0xF1D98A, dark: 0xD5C590), soft: Color(light: 0xF6F1DF, dark: 0x3B3626),
                             deep: Color(light: 0x968240, dark: 0x9D8B4D), paper: Color(light: 0xFBFAF6, dark: 0x1F1E19), tape: Color(light: 0xF2CBD0, dark: 0x4A3A3E))
        case .milktea: Swatch(accent: Color(light: 0xD7C1AA, dark: 0xCEB397), soft: Color(light: 0xF2EBE3, dark: 0x3B3126),
                             deep: Color(light: 0x966C40, dark: 0x9D764D), paper: Color(light: 0xFBF9F6, dark: 0x1F1C19), tape: Color(light: 0xF2CBD0, dark: 0x4A3A3E))
        case .matcha: Swatch(accent: Color(light: 0xBFD0A9, dark: 0xB5C99C), soft: Color(light: 0xEBF1E5, dark: 0x323B26),
                             deep: Color(light: 0x719640, dark: 0x7A9D4D), paper: Color(light: 0xF9FAF7, dark: 0x1C1F19), tape: Color(light: 0xF2CBD0, dark: 0x4A3A3E))        }
    }
}

/// 机の上の色（真っ白・真っ黒・黄ばんだ生成りにしない）
enum Ink {
    /// 文字
    static let text = Color(light: 0x2E3A46, dark: 0xE6EAEE)
    static let sub = Color(light: 0x8E9AA6, dark: 0x98A3AE)
    /// 罫線・カードの線（0.6〜1pt で使う）
    static let rule = Color(light: 0xE3E9EF, dark: 0x2A3138)
    /// ノートの余白の線（淡いピンク）
    static let margin = Color(light: 0xF2CBD0, dark: 0x4A3A3E)
    /// 地（ほぼ白、わずかに青）
    static let paper = Color(light: 0xF3F6F9, dark: 0x121417)
    /// カードの紙
    static let card = Color(light: 0xFCFDFE, dark: 0x1C2024)
    /// 暗記用のマーカー（淡い緑）
    static let marker = Color(light: 0xBFE3CC, dark: 0x3E5F4C)
    /// 差し色（ピーチ）：間違いの ×・今日の分の「済」
    static let peach = Color(light: 0xF4BBA4, dark: 0xC99A88)
    static let peachDeep = Color(light: 0xD38769, dark: 0xDFA086)
    /// 前の版の名前（赤ペン）。いまはピーチの差し色
    static var redPen: Color { peachDeep }
    /// リングの金具
    static let ring = Color(light: 0xC3C9CF, dark: 0x7E858C)
    static let ringShine = Color(light: 0xF2F4F6, dark: 0xC9CDD2)
    /// 主な操作の色（テーマ色の deep）
    static var pen: Color { Tone.current.swatch.deep }
    static var penDeep: Color { Tone.current.swatch.deep }
}

/// 場面の束。色ではなく、アイコンと札の文字で分ける（アプリの色は 1 系統）
enum SceneKind: String, CaseIterable, Identifiable, Sendable {
    case work, travel, daily, feelings, shop, social, mine

    var id: String { rawValue }

    static var bankScenes: [SceneKind] { [.work, .travel, .daily, .feelings, .shop, .social] }

    var title: String {
        switch self {
        case .work: "職場"
        case .travel: "旅行"
        case .daily: "日常"
        case .feelings: "気持ち"
        case .shop: "お店"
        case .social: "人づきあい"
        case .mine: "じぶんのカード"
        }
    }

    var symbol: String {
        switch self {
        case .work: "briefcase"
        case .travel: "airplane"
        case .daily: "house"
        case .feelings: "heart"
        case .shop: "cup.and.saucer"
        case .social: "person.2"
        case .mine: "pencil.line"
        }
    }

    /// どの場面もテーマ色（虹色にしない）
    var swatch: Swatch { Tone.current.swatch }

    init(sceneID: String?) {
        self = sceneID.flatMap(SceneKind.init(rawValue:)) ?? .mine
    }
}

/// 覚えた度合い・練習した量の 5 段階（テーマ色 1 系統の濃さ：罫 → soft → accent 半分 → accent → deep）
enum MarkerLevel {
    static func color(_ level: Int) -> Color {
        let swatch = Tone.current.swatch
        switch min(max(level, 0), 4) {
        case 0: return Ink.rule
        case 1: return swatch.soft
        case 2: return swatch.accent.opacity(0.6)
        case 3: return swatch.accent
        default: return swatch.deep
        }
    }
}

/// 書体：英語・見出し・大きな数字はセリフ、日本語と操作はサンセリフ（Dynamic Type に追従）。太さは regular〜semibold
enum Typo {
    static func english(_ style: Font.TextStyle = .title3) -> Font { .system(style, design: .serif, weight: .medium) }
    static func heading(_ style: Font.TextStyle = .title2) -> Font { .system(style, design: .serif, weight: .semibold) }
    static func number(_ style: Font.TextStyle = .largeTitle) -> Font { .system(style, design: .serif, weight: .regular) }
    static func label(_ style: Font.TextStyle = .footnote) -> Font { .system(style, weight: .medium) }
}

/// 角丸の段階（すべて continuous）
enum Radius {
    static let card: CGFloat = 6
    static let tile: CGFloat = 10
    static let control: CGFloat = 14
    static let panel: CGFloat = 18
}

/// 余白の段階（10〜16 が中心）
enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let readable: CGFloat = 560
}

/// 影は 2 種類だけ、どちらも弱く
extension View {
    func paperShadow() -> some View {
        shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    func liftShadow() -> some View {
        shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
    }
}

/// 主なボタン：テーマ色の deep に白い文字（medium）。押すと少し薄く小さく（easeOut 0.15）
struct InkButtonStyle: ButtonStyle {
    var color: Color = Ink.pen
    var deep: Color = Ink.pen
    var foreground: Color = .white
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(isEnabled ? foreground : Ink.sub)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, Space.l)
            .background(
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .fill(isEnabled ? color : Ink.rule)
            )
            .opacity(pressed ? 0.85 : 1)
            .scaleEffect(pressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: pressed)
    }
}

/// 控えめなボタン：細い線（1pt）の枠に、テーマ色の文字
struct OutlineButtonStyle: ButtonStyle {
    var color: Color = Ink.pen
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, minHeight: 46)
            .padding(.horizontal, Space.m)
            .background(
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous).fill(Ink.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .strokeBorder(Tone.current.swatch.accent, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// 単語の札（並べ替え・聞き取り・選択肢）：白い札に細い線
struct TileButtonStyle: ButtonStyle {
    var fill: Color = Ink.card
    var edge: Color = Ink.rule
    var foreground: Color = Ink.text
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typo.english(.title3))
            .foregroundStyle(foreground)
            .padding(.horizontal, 14)
            .frame(minHeight: 46)
            .background(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).strokeBorder(edge, lineWidth: 0.8))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// 設定で振動を切れる
enum Feel {
    static var hapticsOn: Bool {
        UserDefaults.standard.object(forKey: "settings.haptics") as? Bool ?? true
    }
}
