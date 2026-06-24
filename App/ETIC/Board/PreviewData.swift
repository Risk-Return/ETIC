import Foundation
import DivinationEngine

/// 仅用于 SwiftUI 预览的确定性盘面样例（不参与正式起卦流程）。
enum PreviewData {
    static let board: DivinationBoard = {
        // 固定铜钱背数：含老阳(3背)与老阴(0背)以产生动爻与变卦。
        let cast = Caster.fromCoinBacks([3, 2, 1, 0, 2, 1])
        let pillars = (try? GanzhiCalendar.fourPillars(year: 2024, month: 3, day: 21, hour: 10))
            ?? (try! GanzhiCalendar.fourPillars(year: 2000, month: 1, day: 1, hour: 0))
        return LiuyaoEngine.cast(
            cast,
            pillars: pillars,
            gregorianDescription: "2024年3月21日 10:00",
            question: "近期事业发展如何？",
            category: .career
        )
    }()
}
