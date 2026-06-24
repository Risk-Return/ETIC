import Foundation

/// 干支（Sexagenary cycle）。index 0...59 对应 甲子...癸亥。
public struct Ganzhi: Codable, Hashable, Sendable {
    public let stem: Stem
    public let branch: Branch

    public init(stem: Stem, branch: Branch) {
        self.stem = stem
        self.branch = branch
    }

    /// 由六十甲子序号构造（0 = 甲子）。
    public init(index: Int) {
        let i = ((index % 60) + 60) % 60
        self.stem = Stem(rawValue: i % 10)!
        self.branch = Branch(rawValue: i % 12)!
    }

    public init?(name: String) {
        guard name.count == 2,
              let s = Stem(name: String(name.prefix(1))),
              let b = Branch(name: String(name.suffix(1))) else {
            return nil
        }
        self.stem = s
        self.branch = b
    }

    public var name: String { stem.name + branch.name }

    /// 六十甲子序号（0...59）。并非所有 stem/branch 组合都合法，非法组合返回 nil。
    public var index: Int? {
        for i in 0..<60 where i % 10 == stem.rawValue && i % 12 == branch.rawValue {
            return i
        }
        return nil
    }

    /// 旬空（空亡）的两个地支。
    public var voidBranches: [Branch] {
        guard let idx = index else { return [] }
        let head = idx - (idx % 10)          // 旬首（甲X）序号
        let headBranch = head % 12
        return [
            Branch(rawValue: (headBranch + 10) % 12)!,
            Branch(rawValue: (headBranch + 11) % 12)!
        ]
    }
}
