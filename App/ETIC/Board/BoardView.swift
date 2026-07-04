import SwiftUI
import DivinationEngine

/// 排盘页：展示本卦/变卦六爻、干支、五行、六亲、六神、世应、动爻、旬空、旺衰。
/// `animateReveal` 为 true 时各信息块逐项淡入上浮（M3 信息浮现阶段）；LLM 解读在 M4 接入。
struct BoardView: View {
    @AppStorage("app.language") private var _language: String = AppLanguage.en.rawValue
    let board: DivinationBoard
    var animateReveal: Bool = false

    @State private var showChanged = false
    @State private var revealed = false

    private var hasChanged: Bool { board.changed != nil }

    private var displayed: HexagramView {
        showChanged ? (board.changed ?? board.primary) : board.primary
    }

    var body: some View {
        ZStack {
            InkTheme.paper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    questionHeader.modifier(RevealStep(index: 0, active: animateReveal, revealed: revealed))
                    hexagramTitle.modifier(RevealStep(index: 1, active: animateReveal, revealed: revealed))
                    if hasChanged {
                        primaryChangedToggle.modifier(RevealStep(index: 2, active: animateReveal, revealed: revealed))
                    }
                    boardTable.modifier(RevealStep(index: 3, active: animateReveal, revealed: revealed))
                    legend.modifier(RevealStep(index: 4, active: animateReveal, revealed: revealed))
                    FourPillarsView(castTime: board.castTime)
                        .modifier(RevealStep(index: 5, active: animateReveal, revealed: revealed))
                    if let useGod = board.useGod {
                        UseGodView(useGod: useGod)
                            .modifier(RevealStep(index: 6, active: animateReveal, revealed: revealed))
                    }
                    interpretationEntry.modifier(RevealStep(index: 7, active: animateReveal, revealed: revealed))
                    disclaimer.modifier(RevealStep(index: 8, active: animateReveal, revealed: revealed))
                }
                .padding(20)
            }
        }
        .navigationTitle(L10n.Nav.board)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard animateReveal, !revealed else { revealed = true; return }
            revealed = true
        }
    }

    @ViewBuilder
    private var questionHeader: some View {
        if let question = board.question, !question.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.Board.question)
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
            Text("\(displayed.palace) · \(displayed.palaceElement)  \(displayed.upperTrigram)\(L10n.Board.upperTrigramSuffix)\(displayed.lowerTrigram)\(L10n.Board.lowerTrigramSuffix)  \(board.method)\(L10n.Board.methodSuffix)")
                .font(InkTheme.serifBody(14))
                .foregroundStyle(InkTheme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var primaryChangedToggle: some View {
        Picker("", selection: $showChanged) {
            Text(L10n.Board.primary).tag(false)
            Text(L10n.Board.changed).tag(true)
        }
        .pickerStyle(.segmented)
        .id("boardToggle-\(_language)")
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
        Text(L10n.Board.legend)
            .font(.caption2)
            .foregroundStyle(InkTheme.inkSoft)
    }

    private var interpretationEntry: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.Board.interpretation)
                .font(InkTheme.serifTitle(17))
                .foregroundStyle(InkTheme.ink)
            Text(L10n.Board.interpretationDesc)
                .font(InkTheme.serifBody(14))
                .foregroundStyle(InkTheme.inkSoft)
            NavigationLink {
                InterpretationView(board: board)
            } label: {
                Text(L10n.Board.requestReading)
                    .font(InkTheme.serifBody(15))
                    .foregroundStyle(InkTheme.cinnabar)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(InkTheme.cinnabar.opacity(0.5), lineWidth: 1))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(InkTheme.card, in: RoundedRectangle(cornerRadius: 12))
    }

    private var disclaimer: some View {
        Text(L10n.Board.disclaimer)
            .font(.caption2)
            .foregroundStyle(InkTheme.inkSoft)
    }
}

/// 信息块逐项淡入上浮（带 stagger 延迟）。`active` 为 false 时不改变布局。
private struct RevealStep: ViewModifier {
    let index: Int
    let active: Bool
    let revealed: Bool

    func body(content: Content) -> some View {
        content
            .opacity(active ? (revealed ? 1 : 0) : 1)
            .offset(y: active ? (revealed ? 0 : 14) : 0)
            .animation(.easeOut(duration: 0.45).delay(Double(index) * 0.1), value: revealed)
    }
}

#Preview {
    NavigationStack {
        BoardView(board: PreviewData.board)
    }
}
