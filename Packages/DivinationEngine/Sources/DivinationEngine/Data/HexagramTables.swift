import Foundation

/// 六十四卦静态表：卦名与八宫排盘信息（世应、宫、宫内序）。
public enum HexagramTables {

    public struct PalaceInfo: Sendable {
        public let palace: Trigram   // 所属八宫
        public let order: Int        // 宫内序：0 本宫，1...5 一至五世，6 游魂，7 归魂
        public let world: Int        // 世爻位（1...6）
        public let response: Int     // 应爻位（1...6）
    }

    // MARK: - 卦名

    /// 按（上卦, 下卦）查卦名。
    public static func name(upper: Trigram, lower: Trigram) -> String {
        nameTable[upper]![lower]!
    }

    private static let nameTable: [Trigram: [Trigram: String]] = [
        .qian: [.qian: "乾为天", .dui: "天泽履", .li: "天火同人", .zhen: "天雷无妄",
                .xun: "天风姤", .kan: "天水讼", .gen: "天山遁", .kun: "天地否"],
        .dui: [.qian: "泽天夬", .dui: "兑为泽", .li: "泽火革", .zhen: "泽雷随",
               .xun: "泽风大过", .kan: "泽水困", .gen: "泽山咸", .kun: "泽地萃"],
        .li: [.qian: "火天大有", .dui: "火泽睽", .li: "离为火", .zhen: "火雷噬嗑",
              .xun: "火风鼎", .kan: "火水未济", .gen: "火山旅", .kun: "火地晋"],
        .zhen: [.qian: "雷天大壮", .dui: "雷泽归妹", .li: "雷火丰", .zhen: "震为雷",
                .xun: "雷风恒", .kan: "雷水解", .gen: "雷山小过", .kun: "雷地豫"],
        .xun: [.qian: "风天小畜", .dui: "风泽中孚", .li: "风火家人", .zhen: "风雷益",
               .xun: "巽为风", .kan: "风水涣", .gen: "风山渐", .kun: "风地观"],
        .kan: [.qian: "水天需", .dui: "水泽节", .li: "水火既济", .zhen: "水雷屯",
               .xun: "水风井", .kan: "坎为水", .gen: "水山蹇", .kun: "水地比"],
        .gen: [.qian: "山天大畜", .dui: "山泽损", .li: "山火贲", .zhen: "山雷颐",
               .xun: "山风蛊", .kan: "山水蒙", .gen: "艮为山", .kun: "山地剥"],
        .kun: [.qian: "地天泰", .dui: "地泽临", .li: "地火明夷", .zhen: "地雷复",
               .xun: "地风升", .kan: "地水师", .gen: "地山谦", .kun: "坤为地"]
    ]

    // MARK: - 八宫 / 世应

    /// 八宫顺序（用于宫的呈现）。
    public static let palaceOrder: [Trigram] = [.qian, .kan, .gen, .zhen, .xun, .li, .kun, .dui]

    public static func palaceInfo(code: Int) -> PalaceInfo {
        palaceMap[code]!
    }

    /// 由八宫卦序规则一次性生成 64 卦的宫 / 世应信息。
    static let palaceMap: [Int: PalaceInfo] = {
        var map: [Int: PalaceInfo] = [:]
        for palace in Trigram.allCases {
            let base = palace.rawValue | (palace.rawValue << 3)
            // order 0...5：本宫、一至五世（自下而上依次变爻）
            let worldByOrder = [6, 1, 2, 3, 4, 5]
            var cumulative = 0
            for order in 0...5 {
                if order > 0 { cumulative |= (1 << (order - 1)) }
                let code = base ^ cumulative
                let world = worldByOrder[order]
                map[code] = PalaceInfo(palace: palace, order: order, world: world,
                                       response: response(for: world))
            }
            // 游魂：五世基础上再变第四爻（bit3）
            let fifth = base ^ 0b011111
            let wandering = fifth ^ (1 << 3)
            map[wandering] = PalaceInfo(palace: palace, order: 6, world: 4,
                                        response: response(for: 4))
            // 归魂：游魂基础上下卦三爻还原（变 bit0,1,2）
            let returning = wandering ^ 0b000111
            map[returning] = PalaceInfo(palace: palace, order: 7, world: 3,
                                        response: response(for: 3))
        }
        return map
    }()

    private static func response(for world: Int) -> Int {
        world <= 3 ? world + 3 : world - 3
    }
}
