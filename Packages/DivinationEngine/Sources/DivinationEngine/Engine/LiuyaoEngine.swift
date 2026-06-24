import Foundation

/// 六爻排盘引擎。确定性纯函数：相同输入恒得相同盘面。
public enum LiuyaoEngine {

    /// 排盘。
    /// - Parameters:
    ///   - cast: 起卦结果（六爻）。
    ///   - pillars: 起卦四柱（年月日时干支）。
    ///   - gregorianDescription: 公历时间的可读描述（写入盘面）。
    ///   - question: 占问内容（可选）。
    ///   - category: 占问类别（用于取用神）。
    public static func cast(_ cast: CastResult,
                            pillars: GanzhiCalendar.FourPillars,
                            gregorianDescription: String = "",
                            question: String? = nil,
                            category: QuestionCategory? = nil) -> DivinationBoard {
        let primaryHex = cast.primary
        let movingPositions = cast.movingPositions

        let castTime = CastTimeInfo(
            gregorian: gregorianDescription,
            yearPillar: pillars.year.name,
            monthPillar: pillars.month.name,
            dayPillar: pillars.day.name,
            hourPillar: pillars.hour.name,
            voidBranches: pillars.day.voidBranches.map(\.name)
        )

        let primaryView = hexagramView(
            primaryHex,
            palaceElementForRelatives: primaryHex.palaceElement,
            pillars: pillars,
            lineValues: cast.lines,
            sixGods: SixGod.ladder(dayStem: pillars.day.stem)
        )

        var changedView: HexagramView?
        if !movingPositions.isEmpty {
            let changedHex = cast.changed
            changedView = hexagramView(
                changedHex,
                palaceElementForRelatives: primaryHex.palaceElement, // 变卦六亲以本卦宫为准
                pillars: pillars,
                lineValues: nil,
                sixGods: nil
            )
        }

        var useGod: UseGodSuggestion?
        if let category {
            useGod = useGodSuggestion(category: category, primary: primaryHex, pillars: pillars)
        }

        return DivinationBoard(
            version: DivinationBoard.schemaVersion,
            method: cast.method.rawValue,
            question: question,
            category: category?.rawValue,
            castTime: castTime,
            movingPositions: movingPositions,
            primary: primaryView,
            changed: changedView,
            useGod: useGod
        )
    }

    // MARK: - 单卦排盘

    private static func hexagramView(_ hex: Hexagram,
                                     palaceElementForRelatives: WuXing,
                                     pillars: GanzhiCalendar.FourPillars,
                                     lineValues: [LineValue]?,
                                     sixGods: [SixGod]?) -> HexagramView {
        let najia = Najia.ganzhi(for: hex)
        let voids = Set(pillars.day.voidBranches)
        // voids: Set<Branch>
        let monthElement = pillars.month.branch.element
        let world = hex.worldPosition
        let response = hex.responsePosition

        var lines: [LineView] = []
        for i in 0..<6 {
            let gz = najia[i]
            let element = gz.branch.element
            let relative = SixRelative.of(lineElement: element, selfElement: palaceElementForRelatives)
            let position = i + 1
            lines.append(LineView(
                position: position,
                yinYang: hex.lines[i].rawValue,
                value: lineValues?[i].rawValue,
                moving: lineValues?[i].isMoving ?? false,
                stem: gz.stem.name,
                branch: gz.branch.name,
                element: element.rawValue,
                sixRelative: relative.rawValue,
                sixGod: sixGods?[i].rawValue,
                isWorld: position == world,
                isResponse: position == response,
                isVoid: voids.contains(gz.branch),
                strength: Strength.of(element: element, monthElement: monthElement).rawValue
            ))
        }

        return HexagramView(
            name: hex.name,
            code: hex.code,
            upperTrigram: hex.upperTrigram.name,
            lowerTrigram: hex.lowerTrigram.name,
            palace: hex.palace.name + "宫",
            palaceElement: hex.palaceElement.rawValue,
            worldPosition: world,
            responsePosition: response,
            lines: lines
        )
    }

    // MARK: - 取用神

    private static func useGodSuggestion(category: QuestionCategory,
                                         primary: Hexagram,
                                         pillars: GanzhiCalendar.FourPillars) -> UseGodSuggestion {
        let najia = Najia.ganzhi(for: primary)
        let palaceElement = primary.palaceElement

        let relative: SixRelative
        let rationale: String
        switch category {
        case .career:
            relative = .officer; rationale = "事业功名以官鬼为用神。"
        case .wealth:
            relative = .wealth; rationale = "求财以妻财为用神。"
        case .marriage:
            relative = .wealth; rationale = "婚恋：男占以妻财为用、女占以官鬼为用，默认取妻财。"
        case .health:
            relative = .officer; rationale = "疾病以官鬼为病症、子孙为医药；用神取官鬼。"
        case .study:
            relative = .parent; rationale = "考学以父母（文书）为用神，兼看官鬼功名。"
        case .lawsuit:
            relative = .officer; rationale = "官讼以官鬼为用神。"
        case .travel:
            relative = .parent; rationale = "出行以父母（舟车行装）为用，兼看世爻安危。"
        case .lost:
            relative = .wealth; rationale = "失物多以妻财为用神。"
        case .general:
            let worldElement = najia[primary.worldPosition - 1].branch.element
            relative = SixRelative.of(lineElement: worldElement, selfElement: palaceElement)
            rationale = "综合占以世爻为中心。"
        }

        var positions: [Int] = []
        for i in 0..<6 {
            let element = najia[i].branch.element
            if SixRelative.of(lineElement: element, selfElement: palaceElement) == relative {
                positions.append(i + 1)
            }
        }

        return UseGodSuggestion(
            category: category.rawValue,
            relative: relative.rawValue,
            rationale: rationale,
            positions: positions
        )
    }
}
