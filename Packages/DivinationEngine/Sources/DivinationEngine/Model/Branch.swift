import Foundation

/// 地支（Earthly Branch）。rawValue 0...11 对应 子...亥。
public enum Branch: Int, Codable, CaseIterable, Sendable {
    case zi = 0   // 子
    case chou     // 丑
    case yin      // 寅
    case mao      // 卯
    case chen     // 辰
    case si       // 巳
    case wu       // 午
    case wei      // 未
    case shen     // 申
    case you      // 酉
    case xu       // 戌
    case hai      // 亥

    public var name: String {
        ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"][rawValue]
    }

    public var element: WuXing {
        switch self {
        case .yin, .mao: return .wood
        case .si, .wu: return .fire
        case .chen, .xu, .chou, .wei: return .earth
        case .shen, .you: return .metal
        case .hai, .zi: return .water
        }
    }

    public var yinYang: YinYang {
        rawValue % 2 == 0 ? .yang : .yin
    }

    /// 生肖。
    public var zodiac: String {
        ["鼠", "牛", "虎", "兔", "龙", "蛇", "马", "羊", "猴", "鸡", "狗", "猪"][rawValue]
    }

    public init?(name: String) {
        guard let idx = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"].firstIndex(of: name) else {
            return nil
        }
        self.init(rawValue: idx)
    }
}
