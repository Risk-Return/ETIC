import SwiftUI
import SwiftData
import DivinationEngine

struct CastingView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var model = CastingViewModel()
    @State private var showSettings = false

    var body: some View {
        ZStack {
            InkTheme.paper.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    section(L10n.Casting.questionSection) {
                        TextField(L10n.Casting.questionPlaceholder, text: $model.question, axis: .vertical)
                            .lineLimit(2...4)
                            .font(InkTheme.serifBody(17))
                            .padding(12)
                            .background(InkTheme.card, in: RoundedRectangle(cornerRadius: 10))
                    }

                    section(L10n.Casting.categorySection) {
                        categoryGrid
                    }

                    section(L10n.Casting.methodSection) {
                        methodPicker
                        methodDetail
                    }

                    section(L10n.Casting.timeSection) {
                        DatePicker("", selection: $model.date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(InkTheme.cinnabar)
                    }

                    castButton

                    if let message = model.errorMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(InkTheme.cinnabar)
                    }

                    disclaimer
                }
                .padding(20)
            }
        }
        .navigationTitle(L10n.Nav.cast)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                NavigationLink { HistoryListView() } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .tint(InkTheme.ink)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showSettings = true } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .tint(InkTheme.ink)
            }
        }
        .sheet(isPresented: $showSettings) { RitualSettingsView() }
        .navigationDestination(item: $model.board) { board in
            RitualView(board: board)
        }
        .onChange(of: model.board) { _, newBoard in
            if let newBoard { HistoryStore.recordCast(context, board: newBoard) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.Brand.appName)
                .font(InkTheme.serifTitle(34))
                .foregroundStyle(InkTheme.ink)
            Text(L10n.Brand.tagline)
                .font(InkTheme.serifBody(15))
                .foregroundStyle(InkTheme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(InkTheme.serifTitle(17))
                .foregroundStyle(InkTheme.ink)
            content()
        }
    }

    private var categoryGrid: some View {
        let columns = [GridItem(.adaptive(minimum: 72), spacing: 10)]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(QuestionCategory.allCases, id: \.self) { cat in
                let selected = model.category == cat
                Text(cat.displayName)
                    .font(InkTheme.serifBody(15))
                    .foregroundStyle(selected ? InkTheme.card : InkTheme.ink)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(selected ? InkTheme.cinnabar : InkTheme.card,
                                in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(InkTheme.inkSoft.opacity(0.25), lineWidth: selected ? 0 : 1)
                    )
                    .onTapGesture { model.category = cat }
            }
        }
    }

    private var methodPicker: some View {
        Picker(L10n.Casting.methodSection, selection: $model.method) {
            ForEach(model.methods, id: \.self) { m in
                Text(m.displayName).tag(m)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var methodDetail: some View {
        switch model.method {
        case .coins:
            hint(L10n.Casting.hintCoins)
        case .number:
            HStack(spacing: 12) {
                numberField(L10n.Casting.upperNum, text: $model.upperNumber)
                numberField(L10n.Casting.lowerNum, text: $model.lowerNumber)
            }
            hint(L10n.Casting.hintNumber)
        case .time:
            hint(L10n.Casting.hintTime)
        case .random:
            hint(L10n.Casting.hintRandom)
        default:
            EmptyView()
        }
    }

    private func numberField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.footnote).foregroundStyle(InkTheme.inkSoft)
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(InkTheme.serifBody(18))
                .padding(10)
                .background(InkTheme.card, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(InkTheme.inkSoft)
    }

    private var castButton: some View {
        Button(action: model.cast) {
            Text(L10n.Casting.castButton)
                .font(InkTheme.serifTitle(20))
                .foregroundStyle(InkTheme.card)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(InkTheme.ink, in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(.top, 4)
    }

    private var disclaimer: some View {
        Text(L10n.Casting.disclaimer)
            .font(.caption2)
            .foregroundStyle(InkTheme.inkSoft)
            .padding(.top, 8)
    }
}

extension DivinationBoard: Identifiable {
    public var id: Int {
        var hasher = Hasher()
        hash(into: &hasher)
        return hasher.finalize()
    }
}

#Preview {
    NavigationStack { CastingView() }
}
