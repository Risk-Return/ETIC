import Foundation

/// Central localization namespace. All user-facing strings route through here.
enum L10n {
    enum Nav {
        static let cast = String(localized: "nav.cast")
        static let board = String(localized: "nav.board")
        static let interpret = String(localized: "nav.interpret")
        static let history = String(localized: "nav.history")
        static let record = String(localized: "nav.record")
        static let settings = String(localized: "nav.settings")
    }

    enum Brand {
        static let appName = String(localized: "brand.appName")
        static let tagline = String(localized: "brand.tagline")
    }

    enum Casting {
        static let questionSection = String(localized: "casting.questionSection")
        static let questionPlaceholder = String(localized: "casting.questionPlaceholder")
        static let categorySection = String(localized: "casting.categorySection")
        static let methodSection = String(localized: "casting.methodSection")
        static let timeSection = String(localized: "casting.timeSection")
        static let castButton = String(localized: "casting.castButton")
        static let disclaimer = String(localized: "casting.disclaimer")
        static let hintCoins = String(localized: "casting.hint.coins")
        static let hintNumber = String(localized: "casting.hint.number")
        static let hintTime = String(localized: "casting.hint.time")
        static let hintRandom = String(localized: "casting.hint.random")
        static let upperNum = String(localized: "casting.upperNum")
        static let lowerNum = String(localized: "casting.lowerNum")
    }

    enum Board {
        static let question = String(localized: "board.question")
        static let primary = String(localized: "board.primary")
        static let changed = String(localized: "board.changed")
        static let interpretation = String(localized: "board.interpretation")
        static let interpretationDesc = String(localized: "board.interpretationDesc")
        static let requestReading = String(localized: "board.requestReading")
        static let disclaimer = String(localized: "board.disclaimer")
        static let legend = String(localized: "board.legend")
        static let useGodTitle = String(localized: "board.useGodTitle")
        static let useGodHidden = String(localized: "board.useGodHidden")
        static let useGodPositionPrefix = String(localized: "board.useGodPositionPrefix")
        static let voidPrefix = String(localized: "board.voidPrefix")
        static let yearPillar = String(localized: "board.yearPillar")
        static let monthPillar = String(localized: "board.monthPillar")
        static let dayPillar = String(localized: "board.dayPillar")
        static let hourPillar = String(localized: "board.hourPillar")
        static let upperTrigramSuffix = String(localized: "board.upperTrigramSuffix")
        static let lowerTrigramSuffix = String(localized: "board.lowerTrigramSuffix")
        static let methodSuffix = String(localized: "board.methodSuffix")
        static let world = String(localized: "board.world")
        static let response = String(localized: "board.response")
        static let void = String(localized: "board.void")
    }

    enum Ritual {
        static let preparePrompt = String(localized: "ritual.preparePrompt")
        static let beginCasting = String(localized: "ritual.beginCasting")
        static let casting = String(localized: "ritual.casting")
        static let transformingTitle = String(localized: "ritual.transformingTitle")
        static let formingPlaceholder = String(localized: "ritual.formingPlaceholder")
        static let allLinesDone = String(localized: "ritual.allLinesDone")
        static let shakePrompt = String(localized: "ritual.shakePrompt")
        static let tapPrompt = String(localized: "ritual.tapPrompt")
        static let skipAnimation = String(localized: "ritual.skipAnimation")
        static let coinBack = String(localized: "ritual.coinBack")
        static let coinChar = String(localized: "ritual.coinChar")
    }

    enum Settings {
        static let animationSection = String(localized: "settings.animationSection")
        static let skipAnimation = String(localized: "settings.skipAnimation")
        static let reduceMotionNotice = String(localized: "settings.reduceMotionNotice")
        static let shakeSection = String(localized: "settings.shakeSection")
        static let shakeToToss = String(localized: "settings.shakeToToss")
        static let haptics = String(localized: "settings.haptics")
        static let note = String(localized: "settings.note")
        static let done = String(localized: "settings.done")
    }

    enum Interpret {
        static let placeholder = String(localized: "interpret.placeholder")
        static let masterLabel = String(localized: "interpret.masterLabel")
        static let thinking = String(localized: "interpret.thinking")
        static let scriptureTitle = String(localized: "interpret.scriptureTitle")
        static let scriptureDisclaimer = String(localized: "interpret.scriptureDisclaimer")
    }

    enum History {
        static let emptyTitle = String(localized: "history.emptyTitle")
        static let emptyDesc = String(localized: "history.emptyDesc")
        static let noQuestion = String(localized: "history.noQuestion")
        static let noTranscript = String(localized: "history.noTranscript")
        static let corruptBoard = String(localized: "history.corruptBoard")
        static let transcriptTitle = String(localized: "history.transcriptTitle")
        static let viewBoard = String(localized: "history.viewBoard")
        static let requestReadingFallback = String(localized: "history.requestReadingFallback")
        static let continueAsk = String(localized: "history.continueAsk")
        static let favoritesFilter = String(localized: "history.favoritesFilter")
        static let allFilter = String(localized: "history.allFilter")
        static let favorite = String(localized: "history.favorite")
        static let unfavorite = String(localized: "history.unfavorite")
        static let delete = String(localized: "history.delete")
    }

    enum Error {
        static let invalidNumbers = String(localized: "error.invalidNumbers")
        static let calendarOutOfRange = String(localized: "error.calendarOutOfRange")
        static let badURL = String(localized: "error.badURL")
        static let httpError = String(localized: "error.httpError")
    }
}
