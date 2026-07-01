import SwiftUI
import DivinationEngine

/// 起卦页：选择方法、输入问题与事项类别，起卦后进入排盘页。
struct CastingView: View {
    @StateObject private var model = CastingViewModel()
    @State private var showSettings = false

    var body: some View {
        ZStack {
            InkTheme.paper.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    section("所问何事") {
                        TextField("默念并写下你要占问的事…", text: $model.question, axis: .vertical)
                            .lineLimit(2...4)
                            .font(InkTheme.serifBody(17))
                            .padding(12)
                            .background(InkTheme.card, in: RoundedRectangle(cornerRadius: 10))
                    }

                    section("事项类别") {
                        categoryGrid
                    }

                    section("起卦方法") {
                        methodPicker
                        methodDetail
                    }

                    section("起卦时间") {
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
        .navigationTitle("起卦")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                NavigationLink { EncyclopediaListView() } label: {
                    Image(systemName: "book")
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
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("易卦")
                .font(InkTheme.serifTitle(34))
                .foregroundStyle(InkTheme.ink)
            Text("静心默念所问之事，而后起卦")
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
                Text(cat.rawValue)
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
        Picker("起卦方法", selection: $model.method) {
            ForEach(model.methods, id: \.self) { m in
                Text(m.rawValue).tag(m)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var methodDetail: some View {
        switch model.method {
        case .coins:
            hint("摇一摇手机，三枚铜钱落定六次，自下而上成卦。（M3 接入摇一摇与触觉）")
        case .number:
            HStack(spacing: 12) {
                numberField("上数", text: $model.upperNumber)
                numberField("下数", text: $model.lowerNumber)
            }
            hint("梅花易数：上下数取先天八卦，和数定动爻。")
        case .time:
            hint("以所选时间的干支与月日起卦（梅花时间起卦）。")
        case .random:
            hint("由系统随机模拟摇卦，便于快速体验。")
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
            Text("起　卦")
                .font(InkTheme.serifTitle(20))
                .foregroundStyle(InkTheme.card)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(InkTheme.ink, in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(.top, 4)
    }

    private var disclaimer: some View {
        Text("传统文化娱乐参考，非科学预测。请勿据此做医疗、法律、财务等重大决策。")
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
