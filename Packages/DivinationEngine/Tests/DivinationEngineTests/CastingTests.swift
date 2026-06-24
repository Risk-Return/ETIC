import XCTest
@testable import DivinationEngine

/// 一个可复现的伪随机源（SplitMix64），用于起卦概率与确定性测试。
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

final class CastingTests: XCTestCase {

    // MARK: - 铜钱起卦映射（增删卜易约定）

    func testCoinBacksMapping() {
        XCTAssertEqual(Caster.lineValue(forBacks: 3), .oldYang)
        XCTAssertEqual(Caster.lineValue(forBacks: 2), .youngYin)
        XCTAssertEqual(Caster.lineValue(forBacks: 1), .youngYang)
        XCTAssertEqual(Caster.lineValue(forBacks: 0), .oldYin)
    }

    func testCoinCastPrimaryAndChanged() {
        // 自下而上：老阳, 少阳, 少阳, 少阴, 少阴, 少阴 → 本卦下乾上坤 = 地天泰
        let result = Caster.fromCoinBacks([3, 1, 1, 2, 2, 2])
        XCTAssertEqual(result.primary.name, "地天泰")
        XCTAssertEqual(result.movingPositions, [1])
        // 初爻老阳变阴 → 下卦变为 巽，上坤 = 地风升
        XCTAssertEqual(result.changed.name, "地风升")
    }

    // MARK: - 数字起卦（梅花）

    func testNumberCastDeterministic() {
        // 上 1（乾）下 1（乾），动爻 = (1+1)%6 = 2
        let r = Caster.fromNumbers(upper: 1, lower: 1)
        XCTAssertEqual(r.primary.name, "乾为天")
        XCTAssertEqual(r.movingPositions, [2])
        XCTAssertEqual(r.lines[1], .oldYang)
        // 上 3（离）下 8（坤），动爻 = (3+8)%6 = 5
        let r2 = Caster.fromNumbers(upper: 3, lower: 8)
        XCTAssertEqual(r2.primary.upperTrigram, .li)
        XCTAssertEqual(r2.primary.lowerTrigram, .kun)
        XCTAssertEqual(r2.primary.name, "火地晋")
        XCTAssertEqual(r2.movingPositions, [5])
    }

    // MARK: - 起卦概率分布

    func testCoinDistribution() {
        var gen = SeededGenerator(seed: 0xC0FFEE)
        let trials = 60_000
        var counts: [LineValue: Int] = [:]
        var yangCount = 0
        for _ in 0..<trials {
            let r = Caster.random(using: &gen)
            for line in r.lines {
                counts[line, default: 0] += 1
                if line.yinYang == .yang { yangCount += 1 }
            }
        }
        let total = Double(trials * 6)
        // 三枚硬币模型：老阳 1/8、少阴 3/8、少阳 3/8、老阴 1/8
        assertRatio(Double(counts[.oldYang] ?? 0) / total, expected: 1.0 / 8.0, tol: 0.01, label: "老阳")
        assertRatio(Double(counts[.youngYin] ?? 0) / total, expected: 3.0 / 8.0, tol: 0.015, label: "少阴")
        assertRatio(Double(counts[.youngYang] ?? 0) / total, expected: 3.0 / 8.0, tol: 0.015, label: "少阳")
        assertRatio(Double(counts[.oldYin] ?? 0) / total, expected: 1.0 / 8.0, tol: 0.01, label: "老阴")
        // 阴阳整体应各占约一半
        assertRatio(Double(yangCount) / total, expected: 0.5, tol: 0.01, label: "阳爻占比")
    }

    func testRandomReproducibleWithSeed() {
        var g1 = SeededGenerator(seed: 42)
        var g2 = SeededGenerator(seed: 42)
        let a = Caster.random(using: &g1)
        let b = Caster.random(using: &g2)
        XCTAssertEqual(a.lines, b.lines, "同种子须复现相同卦")
    }

    private func assertRatio(_ value: Double, expected: Double, tol: Double, label: String) {
        XCTAssertEqual(value, expected, accuracy: tol, "\(label) 分布偏离：\(value) vs \(expected)")
    }
}
