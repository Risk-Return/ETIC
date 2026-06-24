import Foundation

/// 六神（六兽）。按日干起，自初爻向上排列。
public enum SixGod: String, Codable, CaseIterable, Sendable {
    case qinglong = "青龙"
    case zhuque = "朱雀"
    case gouchen = "勾陈"
    case tengshe = "螣蛇"
    case baihu = "白虎"
    case xuanwu = "玄武"

    /// 起六神的初爻起点：甲乙起青龙、丙丁起朱雀、戊起勾陈、己起螣蛇、庚辛起白虎、壬癸起玄武。
    public static func startIndex(dayStem: Stem) -> Int {
        switch dayStem {
        case .jia, .yi: return 0   // 青龙
        case .bing, .ding: return 1 // 朱雀
        case .wu: return 2          // 勾陈
        case .ji: return 3          // 螣蛇
        case .geng, .xin: return 4  // 白虎
        case .ren, .gui: return 5   // 玄武
        }
    }

    /// 返回初爻到上爻（index 0...5）对应的六神。
    public static func ladder(dayStem: Stem) -> [SixGod] {
        let start = startIndex(dayStem: dayStem)
        return (0..<6).map { all[(start + $0) % 6] }
    }

    private static let all: [SixGod] = [.qinglong, .zhuque, .gouchen, .tengshe, .baihu, .xuanwu]
}
