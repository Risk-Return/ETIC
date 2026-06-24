import Foundation

/// 纳甲装卦表（京房纳甲）。给定卦中某宫卦的内外卦，确定各爻的天干地支。
public enum Najia {
    /// 内卦（下卦，初二三爻）所纳天干。
    static func innerStem(_ t: Trigram) -> Stem {
        switch t {
        case .qian: return .jia   // 乾纳甲（内）
        case .kun: return .yi     // 坤纳乙（内）
        case .zhen: return .geng  // 震纳庚
        case .xun: return .xin    // 巽纳辛
        case .kan: return .wu     // 坎纳戊
        case .li: return .ji      // 离纳己
        case .gen: return .bing   // 艮纳丙
        case .dui: return .ding   // 兑纳丁
        }
    }

    /// 外卦（上卦，四五六爻）所纳天干。
    static func outerStem(_ t: Trigram) -> Stem {
        switch t {
        case .qian: return .ren   // 乾纳壬（外）
        case .kun: return .gui    // 坤纳癸（外）
        default: return innerStem(t)
        }
    }

    /// 内卦三爻（初→三）地支。
    static func innerBranches(_ t: Trigram) -> [Branch] {
        switch t {
        case .qian: return [.zi, .yin, .chen]
        case .kun: return [.wei, .si, .mao]
        case .zhen: return [.zi, .yin, .chen]
        case .xun: return [.chou, .hai, .you]
        case .kan: return [.yin, .chen, .wu]
        case .li: return [.mao, .chou, .hai]
        case .gen: return [.chen, .wu, .shen]
        case .dui: return [.si, .mao, .chou]
        }
    }

    /// 外卦三爻（四→上）地支。
    static func outerBranches(_ t: Trigram) -> [Branch] {
        switch t {
        case .qian: return [.wu, .shen, .xu]
        case .kun: return [.chou, .hai, .you]
        case .zhen: return [.wu, .shen, .xu]
        case .xun: return [.wei, .si, .mao]
        case .kan: return [.shen, .xu, .zi]
        case .li: return [.you, .wei, .si]
        case .gen: return [.xu, .zi, .yin]
        case .dui: return [.hai, .you, .wei]
        }
    }

    /// 给定一卦，返回各爻（初→上，index 0...5）的干支。
    public static func ganzhi(for hexagram: Hexagram) -> [Ganzhi] {
        let lower = hexagram.lowerTrigram
        let upper = hexagram.upperTrigram
        var result: [Ganzhi] = []
        let lb = innerBranches(lower)
        let ls = innerStem(lower)
        for i in 0..<3 {
            result.append(Ganzhi(stem: ls, branch: lb[i]))
        }
        let ub = outerBranches(upper)
        let us = outerStem(upper)
        for i in 0..<3 {
            result.append(Ganzhi(stem: us, branch: ub[i]))
        }
        return result
    }
}
