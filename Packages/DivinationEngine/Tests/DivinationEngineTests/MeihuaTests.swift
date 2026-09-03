import XCTest
@testable import DivinationEngine

/// 梅花易数体用生克分析测试。
final class MeihuaTests: XCTestCase {

    // 天泽履（上乾下兑），动爻在下卦（pos=3）。
    // 用=下卦兑(金)、体=上卦乾(金)；互卦 风火家人（下互离、上互巽）；变卦 乾为天。
    private func liZhiQian() -> MeihuaView {
        // Caster.meihua(upper:1(乾), lower:2(兑)) → 上乾下兑，动爻 (1+2)%6 = 3
        MeihuaEngine.analyze(primary: Caster.meihua(upper: 1, lower: 2).primary, movingPosition: 3)
    }

    func testTiYongAssignmentByMovingLine() {
        let v = liZhiQian()
        XCTAssertEqual(v.movingPosition, 3)
        // 动爻在下卦 → 用为下卦、体为上卦
        XCTAssertEqual(v.yong.name, "兑")
        XCTAssertEqual(v.yong.position, "下卦")
        XCTAssertEqual(v.ti.name, "乾")
        XCTAssertEqual(v.ti.position, "上卦")
    }

    func testMutualAndChangedHexagrams() {
        let v = liZhiQian()
        // 下互取 2-3-4 爻 = 离，上互取 3-4-5 爻 = 巽 → 互卦 风火家人
        XCTAssertEqual(v.huLower.name, "离")
        XCTAssertEqual(v.huUpper.name, "巽")
        XCTAssertEqual(v.huName, "风火家人")
        // 动爻变后 → 乾为天
        XCTAssertEqual(v.bianName, "乾为天")
        XCTAssertEqual(v.bianYong.name, "乾")
    }

    func testFiveElementRelationsToTi() {
        let v = liZhiQian()
        func rel(_ subject: String) -> MeihuaRelationView { v.relations.first { $0.subject == subject }! }
        // 体乾金：用兑金→比和(吉)；体互巽木→体克(平)；用互离火→克体(凶)；变乾金→比和(吉)
        XCTAssertEqual(rel("用卦").relation, "比和")
        XCTAssertEqual(rel("用卦").favorable, "吉")
        XCTAssertEqual(rel("体互").relation, "体克")
        XCTAssertEqual(rel("用互").relation, "克体")
        XCTAssertEqual(rel("用互").favorable, "凶")
        XCTAssertEqual(rel("变卦").relation, "比和")
    }

    /// 动爻在上卦时，用/体互换。
    func testMovingInUpperSwapsTiYong() {
        // Caster.meihua(upper:1(乾), lower:1(乾)) → 乾为天，动爻 (1+1)%6 = 2（下卦）
        let lower = MeihuaEngine.analyze(primary: Caster.meihua(upper: 1, lower: 1).primary, movingPosition: 2)
        XCTAssertEqual(lower.yong.position, "下卦")
        // 同卦但指定上卦动爻 → 用为上卦
        let upper = MeihuaEngine.analyze(primary: Caster.meihua(upper: 1, lower: 1).primary, movingPosition: 5)
        XCTAssertEqual(upper.yong.position, "上卦")
        XCTAssertEqual(upper.ti.position, "下卦")
    }

    /// 兼容性：梅花起卦经 LiuyaoEngine 排盘后，board.meihua 非空且六爻字段照常。
    func testBoardCarriesMeihuaViewOnlyForMeihua() throws {
        let pillars = try GanzhiCalendar.fourPillars(year: 2024, month: 3, day: 20, hour: 10)
        let meihuaBoard = LiuyaoEngine.cast(Caster.meihua(upper: 3, lower: 8), pillars: pillars, category: .general)
        XCTAssertNotNil(meihuaBoard.meihua, "梅花起卦应附带体用视图")
        XCTAssertEqual(meihuaBoard.meihua?.relations.count, 4)
        XCTAssertEqual(meihuaBoard.version, "1.1.0")
        // 六爻字段仍照常产出
        XCTAssertTrue(meihuaBoard.primary.lines.allSatisfy { !$0.sixRelative.isEmpty })

        // 非梅花起卦不带体用视图
        let numberBoard = LiuyaoEngine.cast(Caster.fromNumbers(upper: 3, lower: 8), pillars: pillars, category: .general)
        XCTAssertNil(numberBoard.meihua)
    }
}
