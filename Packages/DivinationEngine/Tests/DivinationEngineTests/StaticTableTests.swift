import XCTest
@testable import DivinationEngine

/// 静态表 / 规则的快照与一致性测试。
final class StaticTableTests: XCTestCase {

    // MARK: - 五行生克

    func testWuXingCycles() {
        XCTAssertEqual(WuXing.wood.generates, .fire)
        XCTAssertEqual(WuXing.water.generates, .wood)
        XCTAssertEqual(WuXing.wood.controls, .earth)
        XCTAssertEqual(WuXing.metal.controls, .wood)
        for w in WuXing.allCases {
            XCTAssertEqual(w.generatedBy.generates, w)
            XCTAssertEqual(w.controlledBy.controls, w)
        }
    }

    // MARK: - 八卦

    func testTrigramBitsAndElements() {
        XCTAssertEqual(Trigram.qian.rawValue, 0b111)
        XCTAssertEqual(Trigram.kun.rawValue, 0b000)
        XCTAssertEqual(Trigram.li.lines, [.yang, .yin, .yang])
        XCTAssertEqual(Trigram.qian.element, .metal)
        XCTAssertEqual(Trigram.kan.element, .water)
        // 阳卦：乾震坎艮；阴卦：坤巽离兑
        XCTAssertEqual(Trigram.qian.yinYang, .yang)
        XCTAssertEqual(Trigram.zhen.yinYang, .yang)
        XCTAssertEqual(Trigram.kan.yinYang, .yang)
        XCTAssertEqual(Trigram.gen.yinYang, .yang)
        XCTAssertEqual(Trigram.kun.yinYang, .yin)
        XCTAssertEqual(Trigram.xun.yinYang, .yin)
        XCTAssertEqual(Trigram.li.yinYang, .yin)
        XCTAssertEqual(Trigram.dui.yinYang, .yin)
    }

    func testInnateNumberRoundTrip() {
        for t in Trigram.allCases {
            XCTAssertEqual(Trigram.from(innateNumber: t.innateNumber), t)
        }
        XCTAssertEqual(Trigram.from(innateNumber: 8), .kun)   // 8 → 坤
        XCTAssertEqual(Trigram.from(innateNumber: 16), .kun)  // 余 0 → 坤
        XCTAssertEqual(Trigram.from(innateNumber: 9), .qian)  // 余 1 → 乾
    }

    // MARK: - 64 卦名表

    func testHexagramNamesComplete() {
        var names = Set<String>()
        for upper in Trigram.allCases {
            for lower in Trigram.allCases {
                names.insert(HexagramTables.name(upper: upper, lower: lower))
            }
        }
        XCTAssertEqual(names.count, 64, "64 卦名须唯一且齐全")
    }

    func testKnownHexagramNames() {
        XCTAssertEqual(Hexagram(lines: Array(repeating: .yang, count: 6)).name, "乾为天")
        XCTAssertEqual(Hexagram(lines: Array(repeating: .yin, count: 6)).name, "坤为地")
        // 地天泰：下乾上坤
        let tai = Hexagram(lines: [.yang, .yang, .yang, .yin, .yin, .yin])
        XCTAssertEqual(tai.name, "地天泰")
        // 天地否：下坤上乾
        let pi = Hexagram(lines: [.yin, .yin, .yin, .yang, .yang, .yang])
        XCTAssertEqual(pi.name, "天地否")
        // 水火既济：下离上坎
        let jiji = Hexagram(lines: [.yang, .yin, .yang, .yin, .yang, .yin])
        XCTAssertEqual(jiji.name, "水火既济")
    }

    // MARK: - 八宫 / 世应

    func testPalaceMapCovers64AndIsUnique() {
        XCTAssertEqual(HexagramTables.palaceMap.count, 64, "八宫须恰好覆盖 64 卦")
        for code in 0..<64 {
            XCTAssertNotNil(HexagramTables.palaceMap[code], "code \(code) 缺失宫信息")
        }
    }

    func testEightPalacePrincipalHexagrams() {
        // 八宫首卦世爻在上爻（第 6 位）
        for palace in Trigram.allCases {
            let code = palace.rawValue | (palace.rawValue << 3)
            let info = HexagramTables.palaceInfo(code: code)
            XCTAssertEqual(info.palace, palace)
            XCTAssertEqual(info.order, 0)
            XCTAssertEqual(info.world, 6)
            XCTAssertEqual(info.response, 3)
        }
    }

    func testQianPalaceSequence() {
        // 乾宫：乾为天→天风姤→天山遁→天地否→风地观→山地剥→火地晋(游魂)→火天大有(归魂)
        let expected = ["乾为天", "天风姤", "天山遁", "天地否", "风地观", "山地剥", "火地晋", "火天大有"]
        let qian = Trigram.qian
        let base = qian.rawValue | (qian.rawValue << 3)
        var got: [String] = []
        var cumulative = 0
        for order in 0...5 {
            if order > 0 { cumulative |= (1 << (order - 1)) }
            got.append(Hexagram(code: base ^ cumulative).name)
        }
        let wandering = (base ^ 0b011111) ^ (1 << 3)
        got.append(Hexagram(code: wandering).name)
        got.append(Hexagram(code: wandering ^ 0b000111).name)
        XCTAssertEqual(got, expected)
    }

    // MARK: - 纳甲

    func testNajiaQianKun() {
        // 乾为天：甲子 甲寅 甲辰 / 壬午 壬申 壬戌
        let qian = Hexagram(lines: Array(repeating: .yang, count: 6))
        XCTAssertEqual(Najia.ganzhi(for: qian).map(\.name),
                       ["甲子", "甲寅", "甲辰", "壬午", "壬申", "壬戌"])
        // 坤为地：乙未 乙巳 乙卯 / 癸丑 癸亥 癸酉
        let kun = Hexagram(lines: Array(repeating: .yin, count: 6))
        XCTAssertEqual(Najia.ganzhi(for: kun).map(\.name),
                       ["乙未", "乙巳", "乙卯", "癸丑", "癸亥", "癸酉"])
    }

    // MARK: - 六神

    func testSixGodLadder() {
        // 甲乙日起青龙
        XCTAssertEqual(SixGod.ladder(dayStem: .jia).first, .qinglong)
        // 戊日起勾陈
        XCTAssertEqual(SixGod.ladder(dayStem: .wu).first, .gouchen)
        // 壬癸日起玄武
        XCTAssertEqual(SixGod.ladder(dayStem: .gui).first, .xuanwu)
        XCTAssertEqual(SixGod.ladder(dayStem: .jia).count, 6)
    }

    // MARK: - 旬空

    func testVoidBranches() {
        // 甲子旬：空 戌亥
        XCTAssertEqual(Ganzhi(name: "甲子")!.voidBranches.map(\.name), ["戌", "亥"])
        // 甲戌旬：空 申酉
        XCTAssertEqual(Ganzhi(name: "甲戌")!.voidBranches.map(\.name), ["申", "酉"])
        // 甲辰旬：空 寅卯
        XCTAssertEqual(Ganzhi(name: "甲辰")!.voidBranches.map(\.name), ["寅", "卯"])
    }
}
