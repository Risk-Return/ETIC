import SwiftUI
import DivinationEngine

/// 起卦时间四柱与旬空。
struct FourPillarsView: View {
    let castTime: CastTimeInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !castTime.gregorian.isEmpty {
                Text(castTime.gregorian)
                    .font(InkTheme.serifBody(14))
                    .foregroundStyle(InkTheme.inkSoft)
            }
            HStack(spacing: 10) {
                pillar("年", castTime.yearPillar)
                pillar("月", castTime.monthPillar)
                pillar("日", castTime.dayPillar)
                pillar("时", castTime.hourPillar)
            }
            if !castTime.voidBranches.isEmpty {
                Text("旬空：" + castTime.voidBranches.joined(separator: "、"))
                    .font(.footnote)
                    .foregroundStyle(InkTheme.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(InkTheme.card, in: RoundedRectangle(cornerRadius: 12))
    }

    private func pillar(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(InkTheme.inkSoft)
            Text(value).font(InkTheme.serifTitle(18)).foregroundStyle(InkTheme.ink)
        }
        .frame(maxWidth: .infinity)
    }
}
