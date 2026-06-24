import Foundation

/// 八卦（Trigram）。rawValue 为三爻二进制位（bit0 = 初爻 / 最下爻，1 = 阳）。
public enum Trigram: Int, Codable, CaseIterable, Sendable {
    case kun = 0   // ☷ 坤 000
    case zhen = 1  // ☳ 震 001
    case kan = 2   // ☵ 坎 010
    case dui = 3   // ☱ 兑 011
    case gen = 4   // ☶ 艮 100
    case li = 5    // ☲ 离 101
    case xun = 6   // ☴ 巽 110
    case qian = 7  // ☰ 乾 111

    public var name: String {
        switch self {
        case .qian: return "乾"
        case .dui: return "兑"
        case .li: return "离"
        case .zhen: return "震"
        case .xun: return "巽"
        case .kan: return "坎"
        case .gen: return "艮"
        case .kun: return "坤"
        }
    }

    public var symbol: String {
        switch self {
        case .qian: return "☰"
        case .dui: return "☱"
        case .li: return "☲"
        case .zhen: return "☳"
        case .xun: return "☴"
        case .kan: return "☵"
        case .gen: return "☶"
        case .kun: return "☷"
        }
    }

    /// 自然类象。
    public var nature: String {
        switch self {
        case .qian: return "天"
        case .dui: return "泽"
        case .li: return "火"
        case .zhen: return "雷"
        case .xun: return "风"
        case .kan: return "水"
        case .gen: return "山"
        case .kun: return "地"
        }
    }

    public var element: WuXing {
        switch self {
        case .qian, .dui: return .metal
        case .li: return .fire
        case .zhen, .xun: return .wood
        case .kan: return .water
        case .gen, .kun: return .earth
        }
    }

    /// 阳卦（乾震坎艮，阳爻数为奇）/ 阴卦（坤巽离兑，阳爻数为偶）。
    public var yinYang: YinYang {
        let yangCount = (0..<3).filter { rawValue & (1 << $0) != 0 }.count
        return yangCount % 2 == 1 ? .yang : .yin
    }

    /// 先天八卦数（乾1 兑2 离3 震4 巽5 坎6 艮7 坤8）。
    public var innateNumber: Int {
        switch self {
        case .qian: return 1
        case .dui: return 2
        case .li: return 3
        case .zhen: return 4
        case .xun: return 5
        case .kan: return 6
        case .gen: return 7
        case .kun: return 8
        }
    }

    /// 由先天数取卦（用于数字 / 时间起卦）。
    public static func from(innateNumber n: Int) -> Trigram {
        let m = ((n % 8) + 8) % 8
        let idx = m == 0 ? 8 : m
        return [1: .qian, 2: .dui, 3: .li, 4: .zhen, 5: .xun, 6: .kan, 7: .gen, 8: .kun][idx]!
    }

    /// 三爻阴阳（由下至上）。
    public var lines: [YinYang] {
        (0..<3).map { rawValue & (1 << $0) != 0 ? .yang : .yin }
    }
}
