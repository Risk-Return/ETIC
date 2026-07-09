import Foundation

/// 梅花易数（体用生克）分析引擎。确定性纯函数。
///
/// 与六爻纳甲互补：不涉及纳甲/六亲/六神/世应/旬空，
/// 而以**体用分卦 + 互卦 + 变卦 + 五行生克**论事之吉凶倾向。
/// 约定：动爻所在之卦为**用卦**（所占之事），另一卦为**体卦**（求测者自身）。
public enum MeihuaEngine {

    /// 生成梅花体用视图。
    /// - Parameters:
    ///   - primary: 本卦。
    ///   - movingPosition: 单一动爻位（1...6）。
    public static func analyze(primary: Hexagram, movingPosition: Int) -> MeihuaView {
        precondition((1...6).contains(movingPosition), "动爻位须在 1...6")

        let movingInLower = movingPosition <= 3
        let lowerTri = primary.lowerTrigram
        let upperTri = primary.upperTrigram

        // 用卦含动爻，体卦为另一半。
        let yongTri = movingInLower ? lowerTri : upperTri
        let tiTri = movingInLower ? upperTri : lowerTri
        let yongIsLower = movingInLower

        // 互卦：下互取 2-3-4 爻、上互取 3-4-5 爻（爻自下而上，index 0 = 初爻）。
        let ls = primary.lines
        let huLowerTri = trigram(from: [ls[1], ls[2], ls[3]])
        let huUpperTri = trigram(from: [ls[2], ls[3], ls[4]])
        let huHex = Hexagram(lines: huLowerTri.lines + huUpperTri.lines)

        // 体互 / 用互：与体卦同半者为体互，另一半为用互。
        let tiHuTri = yongIsLower ? huUpperTri : huLowerTri
        let yongHuTri = yongIsLower ? huLowerTri : huUpperTri

        // 变卦：动爻变后的本卦；用卦所变之卦代表结果。
        let bianHex = primary.flipping(positions: [movingPosition])
        let bianYongTri = yongIsLower ? bianHex.lowerTrigram : bianHex.upperTrigram

        let tiElement = tiTri.element
        let relations: [MeihuaRelationView] = [
            relation(subject: "用卦", trigram: yongTri, ti: tiElement),
            relation(subject: "体互", trigram: tiHuTri, ti: tiElement),
            relation(subject: "用互", trigram: yongHuTri, ti: tiElement),
            relation(subject: "变卦", trigram: bianYongTri, ti: tiElement),
        ]

        return MeihuaView(
            movingPosition: movingPosition,
            ti: view(tiTri, isLower: !yongIsLower),
            yong: view(yongTri, isLower: yongIsLower),
            huLower: view(huLowerTri, isLower: true),
            huUpper: view(huUpperTri, isLower: false),
            huName: huHex.name,
            bianName: bianHex.name,
            bianYong: view(bianYongTri, isLower: yongIsLower),
            relations: relations,
            summary: summary(ti: tiTri, yong: yongTri, relations: relations)
        )
    }

    // MARK: - 私有

    private static func trigram(from lines: [YinYang]) -> Trigram {
        var c = 0
        for (i, l) in lines.enumerated() where l == .yang { c |= (1 << i) }
        return Trigram(rawValue: c)!
    }

    private static func view(_ t: Trigram, isLower: Bool) -> MeihuaTrigramView {
        MeihuaTrigramView(
            name: t.name,
            symbol: t.symbol,
            nature: t.nature,
            element: t.element.rawValue,
            position: isLower ? "下卦" : "上卦"
        )
    }

    private static func relation(subject: String, trigram: Trigram, ti: WuXing) -> MeihuaRelationView {
        let other = trigram.element
        let rel = ti.relation(to: other)
        let name: String
        let favorable: String
        let note: String
        switch rel {
        case .same:
            name = "比和"; favorable = "吉"
            note = "\(subject)\(trigram.name)（\(other.rawValue)）与体比和，同气相助，较为有利。"
        case .generatesMe:
            name = "生体"; favorable = "吉"
            note = "\(subject)\(trigram.name)（\(other.rawValue)）生体，得其生扶助益。"
        case .controlsMe:
            name = "克体"; favorable = "凶"
            note = "\(subject)\(trigram.name)（\(other.rawValue)）克体，为阻力所在，宜谨慎。"
        case .iGenerate:
            name = "体生"; favorable = "平"
            note = "体生\(subject)\(trigram.name)（\(other.rawValue)），为体卦耗泄之象，主付出。"
        case .iControl:
            name = "体克"; favorable = "平"
            note = "体克\(subject)\(trigram.name)（\(other.rawValue)），体能制之，尚可掌控但耗力。"
        }
        return MeihuaRelationView(
            subject: subject,
            trigram: trigram.name,
            element: other.rawValue,
            relation: name,
            favorable: favorable,
            note: note
        )
    }

    private static func summary(ti: Trigram, yong: Trigram, relations: [MeihuaRelationView]) -> String {
        let support = relations.filter { $0.favorable == "吉" }.count
        let against = relations.filter { $0.favorable == "凶" }.count
        let yongRel = relations.first { $0.subject == "用卦" }?.relation ?? ""

        var tendency: String
        if support > against {
            tendency = "生扶多于克泄，体卦得助，事多趋顺"
        } else if against > support {
            tendency = "克泄多于生扶，体卦受制，事多阻滞，宜守宜缓"
        } else {
            tendency = "生克相当，吉凶互见，宜审时度势"
        }

        return "体卦\(ti.name)（\(ti.element.rawValue)）为求测者自身，用卦\(yong.name)（\(yong.element.rawValue)）为所占之事，二者\(yongRel)。"
            + "综观用、互、变对体：生扶\(support)、克泄\(against)，\(tendency)。"
            + "（梅花以体用生克论倾向，仅供参考，非绝对结论。）"
    }
}
