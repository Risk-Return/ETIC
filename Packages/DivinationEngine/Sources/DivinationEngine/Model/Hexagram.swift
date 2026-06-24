import Foundation

/// 六十四卦之一。`code` 为六爻二进制（bit0 = 初爻 / 最下爻，1 = 阳）。
public struct Hexagram: Codable, Hashable, Sendable {
    /// 六位二进制编码（0...63），bit0 = 初爻。
    public let code: Int

    public init(code: Int) {
        precondition((0...63).contains(code), "hexagram code out of range")
        self.code = code
    }

    /// 由六爻阴阳（自下而上，长度 6）构造。
    public init(lines: [YinYang]) {
        precondition(lines.count == 6, "hexagram needs 6 lines")
        var c = 0
        for (i, l) in lines.enumerated() where l == .yang {
            c |= (1 << i)
        }
        self.code = c
    }

    /// 各爻阴阳（自下而上，index 0 = 初爻）。
    public var lines: [YinYang] {
        (0..<6).map { code & (1 << $0) != 0 ? .yang : .yin }
    }

    /// 下卦（内卦）。
    public var lowerTrigram: Trigram {
        Trigram(rawValue: code & 0b111)!
    }

    /// 上卦（外卦）。
    public var upperTrigram: Trigram {
        Trigram(rawValue: (code >> 3) & 0b111)!
    }

    /// 卦名（如「乾为天」）。
    public var name: String {
        HexagramTables.name(upper: upperTrigram, lower: lowerTrigram)
    }

    /// 所属八宫。
    public var palace: Trigram {
        HexagramTables.palaceInfo(code: code).palace
    }

    /// 卦宫五行。
    public var palaceElement: WuXing {
        palace.element
    }

    /// 世爻位置（1...6）。
    public var worldPosition: Int {
        HexagramTables.palaceInfo(code: code).world
    }

    /// 应爻位置（1...6）。
    public var responsePosition: Int {
        HexagramTables.palaceInfo(code: code).response
    }

    /// 在本宫内的序（0 = 本宫卦，1...5 = 一至五世，6 = 游魂，7 = 归魂）。
    public var palaceOrder: Int {
        HexagramTables.palaceInfo(code: code).order
    }

    /// 翻转指定爻位（1...6）后的新卦。
    public func flipping(positions: [Int]) -> Hexagram {
        var c = code
        for p in positions {
            c ^= (1 << (p - 1))
        }
        return Hexagram(code: c)
    }
}
