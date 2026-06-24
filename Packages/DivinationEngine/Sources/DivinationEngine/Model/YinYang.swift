import Foundation

/// 阴阳。
public enum YinYang: String, Codable, Sendable {
    case yang = "阳"
    case yin = "阴"

    public var opposite: YinYang {
        self == .yang ? .yin : .yang
    }
}
