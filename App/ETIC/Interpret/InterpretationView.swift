import SwiftUI
import DivinationEngine

/// 解读对话页：首轮流式断语 + 多轮追问。盘面只读传入，不重新起卦。
struct InterpretationView: View {
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
        .navigationTitle("大师解读")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.startIfNeeded() }
        .onDisappear { model.cancel() }
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
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
            TextField("就此卦追问…", text: $model.draft, axis: .vertical)
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
                    Text("解卦师")
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
            Text("凝神推演…")
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
}
