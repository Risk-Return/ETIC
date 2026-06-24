import SwiftUI

/// 水墨国风配色与字体。M3 动画前先用静态主题统一观感。
enum InkTheme {
    /// 宣纸底色。
    static let paper = Color(red: 0.96, green: 0.94, blue: 0.89)
    /// 墨色（正文 / 爻象）。
    static let ink = Color(red: 0.13, green: 0.12, blue: 0.11)
    /// 淡墨（次要信息）。
    static let inkSoft = Color(red: 0.45, green: 0.43, blue: 0.40)
    /// 朱砂（动爻 / 世应 / 强调）。
    static let cinnabar = Color(red: 0.78, green: 0.22, blue: 0.16)
    /// 石青（应爻 / 次强调）。
    static let azure = Color(red: 0.18, green: 0.36, blue: 0.45)
    /// 卡片底。
    static let card = Color(red: 0.99, green: 0.98, blue: 0.95)

    /// 标题用衬线字体，营造古典感。
    static func serifTitle(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }

    static func serifBody(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }

    /// 五行配色（用于五行/六亲微标）。
    static func elementColor(_ element: String) -> Color {
        switch element {
        case "木": return Color(red: 0.20, green: 0.50, blue: 0.30)
        case "火": return cinnabar
        case "土": return Color(red: 0.62, green: 0.49, blue: 0.24)
        case "金": return Color(red: 0.55, green: 0.55, blue: 0.58)
        case "水": return azure
        default: return inkSoft
        }
    }
}
