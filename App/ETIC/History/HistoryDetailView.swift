import SwiftUI
import SwiftData
import DivinationEngine

/// 历史卦例详情：盘面快照 + 已保存的解读对话；可继续追问（回写同一记录）。
struct HistoryDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var record: DivinationRecord

    private var board: DivinationBoard? { record.board }

    var body: some View {
        ZStack {
            InkTheme.paper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if let board {
                        NavigationLink { BoardView(board: board) } label: {
                            entryLabel("查看完整盘面", systemImage: "square.grid.3x3")
                        }
                        transcript(board: board)
                    } else {
                        Text("盘面数据已损坏，无法展示。")
                            .font(InkTheme.serifBody(14))
                            .foregroundStyle(InkTheme.cinnabar)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("卦例")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    HistoryStore.toggleFavorite(context, record)
                } label: {
                    Image(systemName: record.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(record.isFavorite ? InkTheme.cinnabar : InkTheme.inkSoft)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(record.title)
                .font(InkTheme.serifTitle(26))
                .foregroundStyle(InkTheme.ink)
            if !record.question.isEmpty {
                Text(record.question)
                    .font(InkTheme.serifBody(16))
                    .foregroundStyle(InkTheme.ink)
            }
            HStack(spacing: 10) {
                if !record.categoryRaw.isEmpty {
                    Text(record.categoryRaw).font(.caption).foregroundStyle(InkTheme.azure)
                }
                Text("\(record.method)起卦").font(.caption).foregroundStyle(InkTheme.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func transcript(board: DivinationBoard) -> some View {
        let turns = record.turns
        VStack(alignment: .leading, spacing: 10) {
            Text("解读记录")
                .font(InkTheme.serifTitle(17))
                .foregroundStyle(InkTheme.ink)
            if turns.isEmpty {
                Text("尚无解读记录。")
                    .font(InkTheme.serifBody(14))
                    .foregroundStyle(InkTheme.inkSoft)
            } else {
                ForEach(turns) { turn in
                    transcriptBubble(turn)
                }
            }
            NavigationLink { InterpretationView(board: board) } label: {
                entryLabel(turns.isEmpty ? "请大师解读" : "继续追问", systemImage: "bubble.left.and.text.bubble.right")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func transcriptBubble(_ turn: StoredTurn) -> some View {
        let isUser = turn.role == .user
        return HStack {
            if isUser { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 4) {
                Text(isUser ? "问" : "解卦师")
                    .font(.caption2)
                    .foregroundStyle(InkTheme.inkSoft)
                Text(turn.text)
                    .font(InkTheme.serifBody(15))
                    .foregroundStyle(InkTheme.ink)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(isUser ? InkTheme.azure.opacity(0.12) : InkTheme.card,
                        in: RoundedRectangle(cornerRadius: 14))
            if !isUser { Spacer(minLength: 40) }
        }
    }

    private func entryLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(InkTheme.serifBody(15))
            .foregroundStyle(InkTheme.cinnabar)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(InkTheme.cinnabar.opacity(0.5), lineWidth: 1))
    }
}
