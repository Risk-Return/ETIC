import Foundation

// `String(localized:)` is only available in Apple-platform Foundation. The engine
// is also built and unit-tested on Linux (that is what CI runs), where this API
// does not exist. This shim lets the existing `String(localized: "some.key")`
// call sites compile on Linux by returning the key verbatim.
//
// It only compiles on non-Apple platforms, so on iOS/macOS the real localized
// lookup (against the app's string catalog) is used unchanged. Display strings
// produced here on Linux are never user-facing — they exist only for tests/CI.
#if !canImport(Darwin)
extension String {
    init(localized key: String) {
        self = key
    }
}
#endif
