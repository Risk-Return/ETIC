import DivinationEngine

// Localized display names for engine enums live in the App layer, not the engine.
// The engine stays pure/deterministic (no UI or localized text); it only exposes
// stable enum values, and the app maps them to user-facing strings via L10n.

extension CastMethod {
    var displayName: String {
        switch self {
        case .coins: return L10n.Method.coins
        case .number: return L10n.Method.number
        case .time: return L10n.Method.time
        case .random: return L10n.Method.random
        case .manual: return L10n.Method.manual
        }
    }
}

extension QuestionCategory {
    var displayName: String {
        switch self {
        case .career: return L10n.Category.career
        case .wealth: return L10n.Category.wealth
        case .marriage: return L10n.Category.marriage
        case .health: return L10n.Category.health
        case .study: return L10n.Category.study
        case .lawsuit: return L10n.Category.lawsuit
        case .travel: return L10n.Category.travel
        case .lost: return L10n.Category.lost
        case .general: return L10n.Category.general
        }
    }
}
