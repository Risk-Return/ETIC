import SwiftUI
import DivinationEngine

/// 排盘页（静态）：展示本卦/变卦六爻、干支、五行、六亲、六神、世应、动爻、旬空、旺衰。
/// 动画在 M3 接入；LLM 解读在 M4 接入（此处先留入口）。
struct BoardView: View {
    let board: DivinationBoard

    @State private var showChanged = false

    private var hasChanged: Bool { board.changed != nil }

    private var displayed: HexagramView {
        showChanged ? (board.changed ?? board.primary) : board.primary
    }

    var body: some View {
        ZStack {
            InkTheme.paper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    questionHeader
                    hexagramTitle
                    if hasChanged { primaryChangedToggle }
                    boardTable
                    legend
                    FourPillarsView(castTime: board.castTime)
                    if let useGod = board.useGod {
                        UseGodView(useGod: useGod)
                    }
                    interpretationPlaceholder
                    disclaimer
                }
                .padding(20)
            }
        }
        .navigationTitle("排盘")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var questionHeader: some View {
        if let question = board.question, !question.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("所问")
                    .font(.caption)
                    .foregroundStyle(InkTheme.inkSoft)
                Text(question)
                    .font(InkTheme.serifBody(17))
                    .foregroundStyle(InkTheme.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var hexagramTitle: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(board.primary.name)
                    .font(InkTheme.serifTitle(28))
                    .foregroundStyle(InkTheme.ink)
                if let changed = board.changed {
                    Image(systemName: "arrow.right")
                        .foregroundStyle(InkTheme.inkSoft)
                    Text(changed.name)
                        .font(InkTheme.serifTitle(22))
                        .foregroundStyle(InkTheme.inkSoft)
                }
            }
            Text("\(displayed.palace) · \(displayed.palaceElement)　\(displayed.upperTrigram)上\(displayed.lowerTrigram)下　\(board.method)起卦")
                .font(InkTheme.serifBody(14))
                .foregroundStyle(InkTheme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var primaryChangedToggle: some View {
        Picker("", selection: $showChanged) {
            Text("本卦").tag(false)
            Text("变卦").tag(true)
        }
        .pickerStyle(.segmented)
    }

    private var boardTable: some View {
        VStack(spacing: 0) {
            // 自上而下渲染：上爻在顶，初爻在底。
            ForEach(displayed.lines.reversed(), id: \.position) { line in
                BoardRowView(line: line, sixGod: sixGod(at: line.position))
                if line.position != 1 {
                    Divider().background(InkTheme.inkSoft.opacity(0.15))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(InkTheme.card, in: RoundedRectangle(cornerRadius: 12))
    }

    /// 六神按爻位定，变卦复用本卦同位六神。
    private func sixGod(at position: Int) -> String? {
        board.primary.lines.first { $0.position == position }?.sixGod
    }

    private var legend: some View {
        Text("○ 老阳动　× 老阴动　世/应 为卦之主客　空 为旬空　旺相休囚死 为月令旺衰")
            .font(.caption2)
            .foregroundStyle(InkTheme.inkSoft)
    }

    private var interpretationPlaceholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("解读")
                .font(InkTheme.serifTitle(17))
                .foregroundStyle(InkTheme.ink)
            Text("大模型解读将在 M4 接入：把这份盘面发给「资深六爻解卦师」，给出断语并支持多轮追问。")
                .font(InkTheme.serifBody(14))
                .foregroundStyle(InkTheme.inkSoft)
            Button {
            } label: {
                Text("请大师解读")
                    .font(InkTheme.serifBody(15))
                    .foregroundStyle(InkTheme.inkSoft)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(InkTheme.inkSoft.opacity(0.4), lineWidth: 1))
            }
            .disabled(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(InkTheme.card, in: RoundedRectangle(cornerRadius: 12))
    }

    private var disclaimer: some View {
        Text("传统文化娱乐参考，非科学预测。")
            .font(.caption2)
            .foregroundStyle(InkTheme.inkSoft)
    }
}

#Preview {
    NavigationStack {
        BoardView(board: PreviewData.board)
    }
}
