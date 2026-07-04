import SwiftUI
import SwiftData
import DivinationEngine

/// 解读对话页：首轮流式断语 + 多轮追问。盘面只读传入，不重新起卦。
struct InterpretationView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var model: InterpretationViewModel

    init(board: DivinationBoard) {
        _model = StateObject(wrappedValue: InterpretationViewModel(board: board))
    }

    var body: some View {
        ZStack {
            InkTheme.paper.ignoresSafeArea()
            VStack(spacing: 0) {
                conversation
                if let error = model.errorMessage {
                    errorBar(error)
                }
                composer
            }
        }
        .navigationTitle(L10n.Nav.interpret)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.startIfNeeded() }
        .onDisappear { model.cancel(); persist() }
        .onChange(of: model.isStreaming) { _, streaming in
            if !streaming { persist() }
        }
    }

    /// 把当前对话回写到历史记录（同盘去重，见 `HistoryStore`）。
    private func persist() {
        let turns = model.turns
            .filter { !$0.text.isEmpty }
            .map { StoredTurn(role: $0.role == .user ? .user : .master, text: $0.text) }
        guard !turns.isEmpty else { return }
        HistoryStore.saveConversation(context, board: model.board, turns: turns)
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if !model.grounding.isEmpty {
                        GroundingSection(items: model.grounding)
                    }
                    ForEach(model.turns) { turn in
                        TurnBubble(turn: turn, streaming: isStreamingTail(turn))
                            .id(turn.id)
                    }
                    if showThinking {
                        ThinkingIndicator().id("thinking")
                    }
                }
                .padding(20)
            }
            .onChange(of: model.turns) { _ in scrollToBottom(proxy) }
            .onChange(of: model.isStreaming) { _ in scrollToBottom(proxy) }
        }
    }

    /// 末条为大师且正在生成 → 显示打字光标。
    private func isStreamingTail(_ turn: InterpretationViewModel.Turn) -> Bool {
        model.isStreaming && turn.id == model.turns.last?.id && turn.role == .master
    }

    /// 最后一条大师气泡尚无文本且正在流式时，显示「凝神推演…」。
    private var showThinking: Bool {
        guard model.isStreaming, let last = model.turns.last else { return false }
        return last.role == .master && last.text.isEmpty
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let lastID = model.turns.last?.id else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(showThinking ? AnyHashable("thinking") : AnyHashable(lastID), anchor: .bottom)
        }
    }

    private func errorBar(_ message: String) -> some View {
        Text(message)
            .font(InkTheme.serifBody(13))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(InkTheme.cinnabar)
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField(L10n.Interpret.placeholder, text: $model.draft, axis: .vertical)
                .font(InkTheme.serifBody(15))
                .lineLimit(1...4)
                .padding(10)
                .background(InkTheme.card, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(InkTheme.inkSoft.opacity(0.25), lineWidth: 1))

            Button {
                model.send()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(model.canSend ? InkTheme.cinnabar : InkTheme.inkSoft.opacity(0.4))
            }
            .disabled(!model.canSend)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(InkTheme.paper)
    }
}

/// 「经文参考」区：展示后端按本卦/动爻/变卦检索到的周易原文，可折叠。
///
/// 只读展示，不参与断卦；断卦仍以盘面世应/用神为准（见 DESIGN §4.2、AGENTS §1）。
private struct GroundingSection: View {
    let items: [LLMService.GroundingItem]
    @State private var expanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 13))
                    Text(L10n.Interpret.scriptureTitle)
                        .font(InkTheme.serifTitle(15))
                    Text("\(items.count)")
                        .font(.caption2)
                        .foregroundStyle(InkTheme.inkSoft)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(InkTheme.inkSoft)
                }
                .foregroundStyle(InkTheme.ink)
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(items) { item in
                        GroundingCard(item: item)
                    }
                    Text(L10n.Interpret.scriptureDisclaimer)
                        .font(.caption2)
                        .foregroundStyle(InkTheme.inkSoft)
                        .padding(.top, 2)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InkTheme.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(InkTheme.cinnabar.opacity(0.25), lineWidth: 1))
    }
}

/// 单条经文卡片：出处标签 + 原文。
private struct GroundingCard: View {
    let item: LLMService.GroundingItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.ref)
                .font(.caption)
                .foregroundStyle(InkTheme.cinnabar)
            Text(item.content)
                .font(InkTheme.serifBody(15))
                .foregroundStyle(InkTheme.ink)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(InkTheme.paper, in: RoundedRectangle(cornerRadius: 10))
    }
}

/// 单条对话气泡。
private struct TurnBubble: View {
    let turn: InterpretationViewModel.Turn
    let streaming: Bool

    private var isUser: Bool { turn.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 4) {
                if !isUser {
                    Text(L10n.Interpret.masterLabel)
                        .font(.caption2)
                        .foregroundStyle(InkTheme.inkSoft)
                }
                Text(turn.text + (streaming ? "▍" : ""))
                    .font(InkTheme.serifBody(16))
                    .foregroundStyle(InkTheme.ink)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(
                isUser ? InkTheme.azure.opacity(0.12) : InkTheme.card,
                in: RoundedRectangle(cornerRadius: 14)
            )
            if !isUser { Spacer(minLength: 40) }
        }
    }
}

/// 流式开始前的「凝神推演」水墨涟漪提示。
private struct ThinkingIndicator: View {
    @State private var phase = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(InkTheme.inkSoft)
                    .frame(width: 7, height: 7)
                    .opacity(phase ? 0.3 : 1)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.2),
                        value: phase
                    )
            }
            Text(L10n.Interpret.thinking)
                .font(InkTheme.serifBody(14))
                .foregroundStyle(InkTheme.inkSoft)
        }
        .padding(.vertical, 4)
        .onAppear { phase = true }
    }
}

#Preview {
    NavigationStack {
        InterpretationView(board: PreviewData.board)
    }
    .modelContainer(for: DivinationRecord.self, inMemory: true)
}
