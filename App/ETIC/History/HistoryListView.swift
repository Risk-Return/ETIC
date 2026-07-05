import SwiftUI
import SwiftData
import DivinationEngine

/// 历史卦例列表：按时间倒序，支持收藏筛选、按事项类别筛选、滑动删除。
struct HistoryListView: View {
    @AppStorage("app.language") private var _language: String = AppLanguage.en.rawValue
    @Environment(\.modelContext) private var context
    @Query(sort: \DivinationRecord.createdAt, order: .reverse)
    private var records: [DivinationRecord]

    @State private var favoritesOnly = false
    @State private var category: String? = nil

    private var filtered: [DivinationRecord] {
        records.filter { record in
            (!favoritesOnly || record.isFavorite) &&
            (category == nil || record.categoryRaw == category)
        }
    }

    /// 出现过的类别（用于筛选条）。
    private var categories: [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for r in records where !r.categoryRaw.isEmpty && !seen.contains(r.categoryRaw) {
            seen.insert(r.categoryRaw)
            ordered.append(r.categoryRaw)
        }
        return ordered
    }

    var body: some View {
        ZStack {
            InkTheme.paper.ignoresSafeArea()
            if records.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    filterBar
                    list
                }
            }
        }
        .navigationTitle(L10n.Nav.history)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(L10n.History.favoritesFilter, selected: favoritesOnly) { favoritesOnly.toggle() }
                Divider().frame(height: 18)
                chip(L10n.History.allFilter, selected: category == nil) { category = nil }
                ForEach(categories, id: \.self) { cat in
                    chip(QuestionCategory(rawValue: cat)?.displayName ?? cat, selected: category == cat) {
                        category = (category == cat) ? nil : cat
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(InkTheme.serifBody(14))
                .foregroundStyle(selected ? InkTheme.card : InkTheme.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? InkTheme.cinnabar : InkTheme.card,
                            in: Capsule())
                .overlay(Capsule().stroke(InkTheme.inkSoft.opacity(0.25),
                                          lineWidth: selected ? 0 : 1))
        }
        .buttonStyle(.plain)
    }

    private var list: some View {
        List {
            ForEach(filtered) { record in
                NavigationLink { HistoryDetailView(record: record) } label: {
                    HistoryRow(record: record)
                }
                .listRowBackground(InkTheme.paper)
                .listRowSeparatorTint(InkTheme.inkSoft.opacity(0.2))
                .swipeActions(edge: .leading) {
                    Button {
                        HistoryStore.toggleFavorite(context, record)
                    } label: {
                        Label(record.isFavorite ? L10n.History.unfavorite : L10n.History.favorite,
                              systemImage: record.isFavorite ? "star.slash" : "star")
                    }
                    .tint(InkTheme.cinnabar)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        HistoryStore.delete(context, record)
                    } label: { Label(L10n.History.delete, systemImage: "trash") }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundStyle(InkTheme.inkSoft)
            Text(L10n.History.emptyTitle)
                .font(InkTheme.serifTitle(18))
                .foregroundStyle(InkTheme.ink)
            Text(L10n.History.emptyDesc)
                .font(InkTheme.serifBody(14))
                .foregroundStyle(InkTheme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

/// 历史列表单行。收藏经滑动操作切换；此处仅以星标指示。
private struct HistoryRow: View {
    let record: DivinationRecord

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if record.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(InkTheme.cinnabar)
                    }
                    Text(record.title)
                        .font(InkTheme.serifTitle(17))
                        .foregroundStyle(InkTheme.ink)
                }
                Text(record.question.isEmpty ? L10n.History.noQuestion : record.question)
                    .font(InkTheme.serifBody(14))
                    .foregroundStyle(InkTheme.inkSoft)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if !record.categoryRaw.isEmpty {
                        Text(QuestionCategory(rawValue: record.categoryRaw)?.displayName ?? record.categoryRaw)
                            .font(.caption2)
                            .foregroundStyle(InkTheme.azure)
                    }
                    Text(Self.dateText(record.createdAt))
                        .font(.caption2)
                        .foregroundStyle(InkTheme.inkSoft)
                }
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private static func dateText(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}

#Preview {
    NavigationStack { HistoryListView() }
        .modelContainer(for: DivinationRecord.self, inMemory: true)
}
