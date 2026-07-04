import Foundation

/// Central localization namespace. All user-facing strings route through here.
enum L10n {
    enum Nav {
        static var cast = String(localized: "nav.cast")
        static var board = String(localized: "nav.board")
        static var interpret = String(localized: "nav.interpret")
        static var history = String(localized: "nav.history")
        static var record = String(localized: "nav.record")
        static var settings = String(localized: "nav.settings")
    }

    enum Brand {
        static var appName = String(localized: "brand.appName")
        static var tagline = String(localized: "brand.tagline")
    }

    enum Casting {
        static var questionSection = String(localized: "casting.questionSection")
        static var questionPlaceholder = String(localized: "casting.questionPlaceholder")
        static var categorySection = String(localized: "casting.categorySection")
        static var methodSection = String(localized: "casting.methodSection")
        static var timeSection = String(localized: "casting.timeSection")
        static var castButton = String(localized: "casting.castButton")
        static var disclaimer = String(localized: "casting.disclaimer")
        static var hintCoins = String(localized: "casting.hint.coins")
        static var hintNumber = String(localized: "casting.hint.number")
        static var hintTime = String(localized: "casting.hint.time")
        static var hintRandom = String(localized: "casting.hint.random")
        static var upperNum = String(localized: "casting.upperNum")
        static var lowerNum = String(localized: "casting.lowerNum")
    }

    enum Method {
        static var coins = String(localized: "casting.method.coins")
        static var number = String(localized: "casting.method.number")
        static var time = String(localized: "casting.method.time")
        static var random = String(localized: "casting.method.random")
        static var manual = String(localized: "casting.method.manual")
    }

    enum Category {
        static var career = String(localized: "category.career")
        static var wealth = String(localized: "category.wealth")
        static var marriage = String(localized: "category.marriage")
        static var health = String(localized: "category.health")
        static var study = String(localized: "category.study")
        static var lawsuit = String(localized: "category.lawsuit")
        static var travel = String(localized: "category.travel")
        static var lost = String(localized: "category.lost")
        static var general = String(localized: "category.general")
    }

    enum Location {
        static var section = String(localized: "location.section")
        static var notSet = String(localized: "location.notSet")
        static var choose = String(localized: "location.choose")
        static var hint = String(localized: "location.hint")
        static var pickerTitle = String(localized: "location.pickerTitle")
        static var search = String(localized: "location.search")
        static var useDeviceTime = String(localized: "location.useDeviceTime")
        static var customSection = String(localized: "location.customSection")
        static var customPlaceholder = String(localized: "location.customPlaceholder")
        static var apply = String(localized: "location.apply")
        static var done = String(localized: "location.done")
        static var customLabel = String(localized: "location.customLabel")
    }

    enum Board {
        static var question = String(localized: "board.question")
        static var primary = String(localized: "board.primary")
        static var changed = String(localized: "board.changed")
        static var interpretation = String(localized: "board.interpretation")
        static var interpretationDesc = String(localized: "board.interpretationDesc")
        static var requestReading = String(localized: "board.requestReading")
        static var disclaimer = String(localized: "board.disclaimer")
        static var legend = String(localized: "board.legend")
        static var useGodTitle = String(localized: "board.useGodTitle")
        static var useGodHidden = String(localized: "board.useGodHidden")
        static var useGodPositionPrefix = String(localized: "board.useGodPositionPrefix")
        static var voidPrefix = String(localized: "board.voidPrefix")
        static var yearPillar = String(localized: "board.yearPillar")
        static var monthPillar = String(localized: "board.monthPillar")
        static var dayPillar = String(localized: "board.dayPillar")
        static var hourPillar = String(localized: "board.hourPillar")
        static var upperTrigramSuffix = String(localized: "board.upperTrigramSuffix")
        static var lowerTrigramSuffix = String(localized: "board.lowerTrigramSuffix")
        static var methodSuffix = String(localized: "board.methodSuffix")
        static var world = String(localized: "board.world")
        static var response = String(localized: "board.response")
        static var void = String(localized: "board.void")
    }

    enum Ritual {
        static var preparePrompt = String(localized: "ritual.preparePrompt")
        static var beginCasting = String(localized: "ritual.beginCasting")
        static var casting = String(localized: "ritual.casting")
        static var transformingTitle = String(localized: "ritual.transformingTitle")
        static var formingPlaceholder = String(localized: "ritual.formingPlaceholder")
        static var allLinesDone = String(localized: "ritual.allLinesDone")
        static var shakePrompt = String(localized: "ritual.shakePrompt")
        static var tapPrompt = String(localized: "ritual.tapPrompt")
        static var skipAnimation = String(localized: "ritual.skipAnimation")
        static var coinBack = String(localized: "ritual.coinBack")
        static var coinChar = String(localized: "ritual.coinChar")
    }

    enum Settings {
        static var animationSection = String(localized: "settings.animationSection")
        static var skipAnimation = String(localized: "settings.skipAnimation")
        static var reduceMotionNotice = String(localized: "settings.reduceMotionNotice")
        static var shakeSection = String(localized: "settings.shakeSection")
        static var shakeToToss = String(localized: "settings.shakeToToss")
        static var haptics = String(localized: "settings.haptics")
        static var note = String(localized: "settings.note")
        static var done = String(localized: "settings.done")
        static var languageSection = String(localized: "settings.languageSection")
        static var languageLabel = String(localized: "settings.languageLabel")
    }

    enum Encyclopedia {
        static var title = String(localized: "encyclopedia.title")
        static var searchPrompt = String(localized: "encyclopedia.searchPrompt")
        static var missingData = String(localized: "encyclopedia.missingData")
        static var judgmentTitle = String(localized: "encyclopedia.judgmentTitle")
        static var tuanTitle = String(localized: "encyclopedia.tuanTitle")
        static var linesTitle = String(localized: "encyclopedia.linesTitle")
        static var disclaimer = String(localized: "encyclopedia.disclaimer")
    }

    enum Interpret {
        static var placeholder = String(localized: "interpret.placeholder")
        static var masterLabel = String(localized: "interpret.masterLabel")
        static var thinking = String(localized: "interpret.thinking")
        static var scriptureTitle = String(localized: "interpret.scriptureTitle")
        static var scriptureDisclaimer = String(localized: "interpret.scriptureDisclaimer")
    }

    enum History {
        static var emptyTitle = String(localized: "history.emptyTitle")
        static var emptyDesc = String(localized: "history.emptyDesc")
        static var noQuestion = String(localized: "history.noQuestion")
        static var noTranscript = String(localized: "history.noTranscript")
        static var corruptBoard = String(localized: "history.corruptBoard")
        static var transcriptTitle = String(localized: "history.transcriptTitle")
        static var viewBoard = String(localized: "history.viewBoard")
        static var requestReadingFallback = String(localized: "history.requestReadingFallback")
        static var continueAsk = String(localized: "history.continueAsk")
        static var favoritesFilter = String(localized: "history.favoritesFilter")
        static var allFilter = String(localized: "history.allFilter")
        static var favorite = String(localized: "history.favorite")
        static var unfavorite = String(localized: "history.unfavorite")
        static var delete = String(localized: "history.delete")
    }

    enum Error {
        static var invalidNumbers = String(localized: "error.invalidNumbers")
        static var calendarOutOfRange = String(localized: "error.calendarOutOfRange")
        static var badURL = String(localized: "error.badURL")
        static var httpError = String(localized: "error.httpError")
    }
}
