import Foundation

/// 天干（Heavenly Stem）。rawValue 0...9 对应 甲...癸。
public enum Stem: Int, Codable, CaseIterable, Sendable {
    case jia = 0   // 甲
    case yi        // 乙
    case bing      // 丙
    case ding      // 丁
    case wu        // 戊
    case ji        // 己
    case geng      // 庚
    case xin       // 辛
    case ren       // 壬
    case gui       // 癸

    public var name: String {
        ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"][rawValue]
    }

    public var element: WuXing {
        switch self {
        case .jia, .yi: return .wood
        case .bing, .ding: return .fire
        case .wu, .ji: return .earth
        case .geng, .xin: return .metal
        case .ren, .gui: return .water
        }
    }

    public var yinYang: YinYang {
        rawValue % 2 == 0 ? .yang : .yin
    }

    public init?(name: String) {
        guard let idx = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"].firstIndex(of: name) else {
            return nil
        }
        self.init(rawValue: idx)
    }
}
