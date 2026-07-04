import SwiftUI

/// 卦象百科列表：64 卦网格，支持按卦名 / 卦辞搜索。纯浏览，离线。
struct EncyclopediaListView: View {
    @AppStorage("app.language") private var _language: String = AppLanguage.en.rawValue
    @State private var query = ""

    private var results: [HexagramLore] { EncyclopediaStore.search(query) }

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 12)]

    var body: some View {
        ZStack {
            InkTheme.paper.ignoresSafeArea()
            if EncyclopediaStore.all.isEmpty {
                Text(L10n.Encyclopedia.missingData)
                    .font(InkTheme.serifBody(15))
                    .foregroundStyle(InkTheme.cinnabar)
                    .padding()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(results) { lore in
                            NavigationLink { EncyclopediaDetailView(lore: lore) } label: {
                                cell(lore)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle(L10n.Encyclopedia.title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: L10n.Encyclopedia.searchPrompt)
    }

    private func cell(_ lore: HexagramLore) -> some View {
        VStack(spacing: 6) {
            Text(lore.short)
                .font(InkTheme.serifTitle(30))
                .foregroundStyle(InkTheme.ink)
            Text(lore.name)
                .font(InkTheme.serifBody(13))
                .foregroundStyle(InkTheme.inkSoft)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(InkTheme.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(InkTheme.inkSoft.opacity(0.15), lineWidth: 1))
    }
}

#Preview {
    NavigationStack { EncyclopediaListView() }
}
