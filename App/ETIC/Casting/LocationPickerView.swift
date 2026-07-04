import SwiftUI

/// Sheet for choosing a casting longitude — pick a major world city or enter a
/// custom longitude. Drives true-solar-time correction in the engine.
struct LocationPickerView: View {
    @ObservedObject var model: CastingViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var customText = ""

    private var groups: [WorldCities.Group] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return WorldCities.groups }
        return WorldCities.groups.compactMap { group in
            let filtered = group.cities.filter {
                $0.name.localizedCaseInsensitiveContains(q) ||
                $0.region.localizedCaseInsensitiveContains(q)
            }
            return filtered.isEmpty ? nil : WorldCities.Group(name: group.name, cities: filtered)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(L10n.Location.useDeviceTime) {
                        model.clearLocation()
                        dismiss()
                    }
                    .foregroundStyle(model.longitude == nil ? InkTheme.inkSoft : InkTheme.cinnabar)
                }

                Section(L10n.Location.customSection) {
                    HStack {
                        TextField(L10n.Location.customPlaceholder, text: $customText)
                            .keyboardType(.numbersAndPunctuation)
                        Button(L10n.Location.apply) {
                            if let v = Double(customText.trimmingCharacters(in: .whitespaces)),
                               (-180...180).contains(v) {
                                model.setCustomLongitude(v)
                                dismiss()
                            }
                        }
                        .disabled(Double(customText.trimmingCharacters(in: .whitespaces)).map { !(-180...180).contains($0) } ?? true)
                    }
                }

                ForEach(groups) { group in
                    Section(group.name) {
                        ForEach(group.cities) { city in
                            Button {
                                model.selectCity(city)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(city.name).foregroundStyle(InkTheme.ink)
                                        Text(city.region)
                                            .font(.caption)
                                            .foregroundStyle(InkTheme.inkSoft)
                                    }
                                    Spacer()
                                    Text(city.longitudeText)
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(InkTheme.inkSoft)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: L10n.Location.search)
            .navigationTitle(L10n.Location.pickerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Location.done) { dismiss() }
                }
            }
        }
    }
}
