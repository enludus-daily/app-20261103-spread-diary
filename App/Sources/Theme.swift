import SwiftUI
import UIKit

// 見た目の決まり（.claude/skills/app-quality-bar/references/look.md §2〜4）。
// 世界観：このアプリでは〔リング綴じの単語カード〕が〔フレーズ 1 つ〕になり、〔赤シート〕が〔答えを隠して思い出す操作〕になる。
// グラデーションは使わない。色は場面の束ごとに 5 段階、覚えた度合いはマーカーの濃さ 5 段階で表す。

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

/// 机の上の道具の色（真っ白・真っ黒にしない）
enum Ink {
    /// 文字（ボールペンの紺）
    static let text = Color(light: 0x26303B, dark: 0xECE6DA)
    static let sub = Color(light: 0x7D8590, dark: 0xA29D92)
    /// ノートの罫線（青）
    static let rule = Color(light: 0xD3E0EC, dark: 0x323B45)
    /// ノートの余白の線（赤）
    static let margin = Color(light: 0xEBB0AE, dark: 0x6E4140)
    /// ノートの地
    static let paper = Color(light: 0xFBF8F1, dark: 0x1A1916)
    /// カードの紙
    static let card = Color(light: 0xFFFEFA, dark: 0x27251F)
    /// 赤シート（multiply で重ねる）
    static let redSheet = Color(rgb: 0xE0283A)
    /// 緑のマーカー（答えの英語に引く）
    static let marker = Color(light: 0x56C98A, dark: 0x2F8F5B)
    /// 赤ペン・判子
    static let redPen = Color(light: 0xD3343E, dark: 0xF06A70)
    /// リングの金具
    static let ring = Color(light: 0xA9AFB6, dark: 0x868C93)
    static let ringShine = Color(light: 0xF2F4F6, dark: 0xC9CDD2)
    /// 主な操作の色（ボールペンの紺）
    static let pen = Color(light: 0x2F5D8A, dark: 0x8DB4DA)
    static let penDeep = Color(light: 0x23476B, dark: 0x5F8DB8)
}

/// 1 色の 5 段階（accent 主 / soft 淡い地 / deep 白文字が読める濃さ / paper 紙の地 / tape 飾り）
struct Swatch: Sendable {
    let accent: Color
    let soft: Color
    let deep: Color
    let paper: Color
    let tape: Color
}

/// 場面の束。カードの色が束ごとに違う（市販の単語カードの色違いのリング）
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

    var swatch: Swatch {
        switch self {
        case .work: Swatch(accent: Color(light: 0x6E9CCB, dark: 0x7FA9D4), soft: Color(light: 0xDCE8F4, dark: 0x22303E),
                           deep: Color(light: 0x2F5D8A, dark: 0x4C7AA8), paper: Color(light: 0xF2F6FB, dark: 0x1E242B), tape: Color(light: 0xF2CBD0, dark: 0x6B4A4F))
        case .travel: Swatch(accent: Color(light: 0x5DB3A0, dark: 0x6FC2AF), soft: Color(light: 0xD7EFE9, dark: 0x1F3531),
                             deep: Color(light: 0x24786A, dark: 0x3E9584), paper: Color(light: 0xF0F8F5, dark: 0x1B2623), tape: Color(light: 0xF6DDA4, dark: 0x6B5A35))
        case .daily: Swatch(accent: Color(light: 0xE6BE4C, dark: 0xE8C761), soft: Color(light: 0xFAEFC9, dark: 0x3A3220),
                            deep: Color(light: 0x8F6A0C, dark: 0xB08A2A), paper: Color(light: 0xFDF9EC, dark: 0x27231A), tape: Color(light: 0xBFD9F0, dark: 0x3E5266))
        case .feelings: Swatch(accent: Color(light: 0xE88AA2, dark: 0xEC9AAF), soft: Color(light: 0xF9DDE4, dark: 0x3C2329),
                               deep: Color(light: 0xB03A5B, dark: 0xC85574), paper: Color(light: 0xFDF3F5, dark: 0x2A1E21), tape: Color(light: 0xCDE8C9, dark: 0x41583E))
        case .shop: Swatch(accent: Color(light: 0xEE9A5B, dark: 0xF0A870), soft: Color(light: 0xFBE3D0, dark: 0x3D2A1E),
                           deep: Color(light: 0xB25A1B, dark: 0xC8732F), paper: Color(light: 0xFEF5EE, dark: 0x2A2019), tape: Color(light: 0xD7CFF2, dark: 0x4D4766))
        case .social: Swatch(accent: Color(light: 0x9C8BD6, dark: 0xAC9DDE), soft: Color(light: 0xE6E1F6, dark: 0x2D2840),
                             deep: Color(light: 0x5B48A3, dark: 0x7764BD), paper: Color(light: 0xF5F3FC, dark: 0x221F2C), tape: Color(light: 0xF7D3B6, dark: 0x6B5040))
        case .mine: Swatch(accent: Color(light: 0x8C949C, dark: 0x9EA5AC), soft: Color(light: 0xE6E8EA, dark: 0x2C2F33),
                           deep: Color(light: 0x4A525A, dark: 0x6D757D), paper: Color(light: 0xF7F7F6, dark: 0x222324), tape: Color(light: 0xF6DDA4, dark: 0x6B5A35))
        }
    }

    init(sceneID: String?) {
        self = sceneID.flatMap(SceneKind.init(rawValue:)) ?? .mine
    }
}

/// 覚えた度合い・練習した量の 5 段階（緑のマーカーの濃さ）
enum MarkerLevel {
    static let colors: [Color] = [
        Color(light: 0xE9EEF2, dark: 0x2A2E33),
        Color(light: 0xC6EBD5, dark: 0x1F4A33),
        Color(light: 0x8FD8AE, dark: 0x2B6E49),
        Color(light: 0x52BE83, dark: 0x3E9E68),
        Color(light: 0x23925A, dark: 0x6BD49A),
    ]

    static func color(_ level: Int) -> Color {
        colors[min(max(level, 0), colors.count - 1)]
    }
}

/// 書体：英語・見出し・大きな数字はセリフ、日本語と操作はサンセリフ（Dynamic Type に追従）
enum Typo {
    static func english(_ style: Font.TextStyle = .title3) -> Font { .system(style, design: .serif, weight: .semibold) }
    static func heading(_ style: Font.TextStyle = .title2) -> Font { .system(style, design: .serif, weight: .bold) }
    static func number(_ style: Font.TextStyle = .largeTitle) -> Font { .system(style, design: .serif, weight: .bold) }
    static func label(_ style: Font.TextStyle = .footnote) -> Font { .system(style, weight: .medium) }
}

/// 角丸の段階（すべて continuous）
enum Radius {
    /// 単語カード（実物に近い小さな角）
    static let card: CGFloat = 6
    /// 札・小さなボタン
    static let tile: CGFloat = 10
    /// ボタン・入力欄
    static let control: CGFloat = 12
    /// ノートの区切り・シート
    static let panel: CGFloat = 18
}

/// 余白の段階
enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    /// 大きな画面で主役の幅を抑える
    static let readable: CGFloat = 560
}

/// 影は 2 種類だけ：置いた紙・浮かせた紙
extension View {
    func paperShadow() -> some View {
        shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
    }

    func liftShadow() -> some View {
        shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 8)
    }
}

/// 主なボタン：濃い色の札。押すと 0.94 倍に縮み、下辺の厚み（3pt）が消える（キーを押す感じ）
struct InkButtonStyle: ButtonStyle {
    var color: Color = Ink.pen
    var deep: Color = Ink.penDeep
    var foreground: Color = .white
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.headline)
            .foregroundStyle(isEnabled ? foreground : Ink.sub)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, Space.l)
            .background(
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .fill(isEnabled ? color : Ink.rule)
            )
            .background(
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .fill(isEnabled ? deep : Ink.rule)
                    .offset(y: pressed ? 0 : 3)
            )
            .offset(y: pressed ? 3 : 0)
            .scaleEffect(pressed && !reduceMotion ? 0.94 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.6), value: pressed)
    }
}

/// 控えめなボタン：罫線の上に鉛筆で書いた枠
struct OutlineButtonStyle: ButtonStyle {
    var color: Color = Ink.pen
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, Space.m)
            .background(
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .fill(Ink.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .strokeBorder(color.opacity(0.5), lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// 単語の札（並べ替え・聞き取り・選択肢）：紙の札、下辺だけ 3pt 厚い
struct TileButtonStyle: ButtonStyle {
    var fill: Color = Ink.card
    var edge: Color = Ink.rule
    var foreground: Color = Ink.text
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(Typo.english(.title3))
            .foregroundStyle(foreground)
            .padding(.horizontal, 14)
            .frame(minHeight: 46)
            .background(
                RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).fill(fill)
            )
            .background(
                RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).fill(edge).offset(y: pressed ? 0 : 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).strokeBorder(edge, lineWidth: 1)
            )
            .offset(y: pressed ? 3 : 0)
            .scaleEffect(pressed && !reduceMotion ? 0.94 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.55), value: pressed)
    }
}

/// 設定で振動を切れる
enum Feel {
    static var hapticsOn: Bool {
        UserDefaults.standard.object(forKey: "settings.haptics") as? Bool ?? true
    }
}
