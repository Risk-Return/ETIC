import Foundation

/// Central localization namespace. All user-facing strings route through here.
enum L10n {
    enum Nav {
        static var cast: String { LocalizationStore.string("nav.cast") }
        static var board: String { LocalizationStore.string("nav.board") }
        static var interpret: String { LocalizationStore.string("nav.interpret") }
        static var history: String { LocalizationStore.string("nav.history") }
        static var record: String { LocalizationStore.string("nav.record") }
        static var settings: String { LocalizationStore.string("nav.settings") }
        static var account: String { LocalizationStore.string("nav.account") }
    }

    enum Brand {
        static var appName: String { LocalizationStore.string("brand.appName") }
        static var tagline: String { LocalizationStore.string("brand.tagline") }
    }

    enum Casting {
        static var questionSection: String { LocalizationStore.string("casting.questionSection") }
        static var questionPlaceholder: String { LocalizationStore.string("casting.questionPlaceholder") }
        static var categorySection: String { LocalizationStore.string("casting.categorySection") }
        static var methodSection: String { LocalizationStore.string("casting.methodSection") }
        static var timeSection: String { LocalizationStore.string("casting.timeSection") }
        static var castButton: String { LocalizationStore.string("casting.castButton") }
        static var disclaimer: String { LocalizationStore.string("casting.disclaimer") }
        static var hintCoins: String { LocalizationStore.string("casting.hint.coins") }
        static var hintNumber: String { LocalizationStore.string("casting.hint.number") }
        static var hintTime: String { LocalizationStore.string("casting.hint.time") }
        static var hintRandom: String { LocalizationStore.string("casting.hint.random") }
        static var upperNum: String { LocalizationStore.string("casting.upperNum") }
        static var lowerNum: String { LocalizationStore.string("casting.lowerNum") }
    }

    enum Method {
        static var coins: String { LocalizationStore.string("casting.method.coins") }
        static var number: String { LocalizationStore.string("casting.method.number") }
        static var time: String { LocalizationStore.string("casting.method.time") }
        static var random: String { LocalizationStore.string("casting.method.random") }
        static var manual: String { LocalizationStore.string("casting.method.manual") }
    }

    enum Category {
        static var career: String { LocalizationStore.string("category.career") }
        static var wealth: String { LocalizationStore.string("category.wealth") }
        static var marriage: String { LocalizationStore.string("category.marriage") }
        static var health: String { LocalizationStore.string("category.health") }
        static var study: String { LocalizationStore.string("category.study") }
        static var lawsuit: String { LocalizationStore.string("category.lawsuit") }
        static var travel: String { LocalizationStore.string("category.travel") }
        static var lost: String { LocalizationStore.string("category.lost") }
        static var general: String { LocalizationStore.string("category.general") }
    }

    enum Location {
        static var section: String { LocalizationStore.string("location.section") }
        static var notSet: String { LocalizationStore.string("location.notSet") }
        static var choose: String { LocalizationStore.string("location.choose") }
        static var hint: String { LocalizationStore.string("location.hint") }
        static var pickerTitle: String { LocalizationStore.string("location.pickerTitle") }
        static var search: String { LocalizationStore.string("location.search") }
        static var useDeviceTime: String { LocalizationStore.string("location.useDeviceTime") }
        static var customSection: String { LocalizationStore.string("location.customSection") }
        static var customPlaceholder: String { LocalizationStore.string("location.customPlaceholder") }
        static var apply: String { LocalizationStore.string("location.apply") }
        static var done: String { LocalizationStore.string("location.done") }
        static var customLabel: String { LocalizationStore.string("location.customLabel") }
    }

    enum Board {
        static var question: String { LocalizationStore.string("board.question") }
        static var primary: String { LocalizationStore.string("board.primary") }
        static var changed: String { LocalizationStore.string("board.changed") }
        static var interpretation: String { LocalizationStore.string("board.interpretation") }
        static var interpretationDesc: String { LocalizationStore.string("board.interpretationDesc") }
        static var requestReading: String { LocalizationStore.string("board.requestReading") }
        static var disclaimer: String { LocalizationStore.string("board.disclaimer") }
        static var legend: String { LocalizationStore.string("board.legend") }
        static var useGodTitle: String { LocalizationStore.string("board.useGodTitle") }
        static var useGodHidden: String { LocalizationStore.string("board.useGodHidden") }
        static var useGodPositionPrefix: String { LocalizationStore.string("board.useGodPositionPrefix") }
        static var voidPrefix: String { LocalizationStore.string("board.voidPrefix") }
        static var yearPillar: String { LocalizationStore.string("board.yearPillar") }
        static var monthPillar: String { LocalizationStore.string("board.monthPillar") }
        static var dayPillar: String { LocalizationStore.string("board.dayPillar") }
        static var hourPillar: String { LocalizationStore.string("board.hourPillar") }
        static var upperTrigramSuffix: String { LocalizationStore.string("board.upperTrigramSuffix") }
        static var lowerTrigramSuffix: String { LocalizationStore.string("board.lowerTrigramSuffix") }
        static var methodSuffix: String { LocalizationStore.string("board.methodSuffix") }
        static var world: String { LocalizationStore.string("board.world") }
        static var response: String { LocalizationStore.string("board.response") }
        static var void: String { LocalizationStore.string("board.void") }
    }

    enum Ritual {
        static var preparePrompt: String { LocalizationStore.string("ritual.preparePrompt") }
        static var beginCasting: String { LocalizationStore.string("ritual.beginCasting") }
        static var casting: String { LocalizationStore.string("ritual.casting") }
        static var transformingTitle: String { LocalizationStore.string("ritual.transformingTitle") }
        static var formingPlaceholder: String { LocalizationStore.string("ritual.formingPlaceholder") }
        static var allLinesDone: String { LocalizationStore.string("ritual.allLinesDone") }
        static var shakePrompt: String { LocalizationStore.string("ritual.shakePrompt") }
        static var tapPrompt: String { LocalizationStore.string("ritual.tapPrompt") }
        static var skipAnimation: String { LocalizationStore.string("ritual.skipAnimation") }
        static var coinBack: String { LocalizationStore.string("ritual.coinBack") }
        static var coinChar: String { LocalizationStore.string("ritual.coinChar") }
    }

    enum Settings {
        static var animationSection: String { LocalizationStore.string("settings.animationSection") }
        static var skipAnimation: String { LocalizationStore.string("settings.skipAnimation") }
        static var reduceMotionNotice: String { LocalizationStore.string("settings.reduceMotionNotice") }
        static var shakeSection: String { LocalizationStore.string("settings.shakeSection") }
        static var shakeToToss: String { LocalizationStore.string("settings.shakeToToss") }
        static var haptics: String { LocalizationStore.string("settings.haptics") }
        static var note: String { LocalizationStore.string("settings.note") }
        static var done: String { LocalizationStore.string("settings.done") }
        static var languageSection: String { LocalizationStore.string("settings.languageSection") }
        static var languageLabel: String { LocalizationStore.string("settings.languageLabel") }
    }

    enum Encyclopedia {
        static var title: String { LocalizationStore.string("encyclopedia.title") }
        static var searchPrompt: String { LocalizationStore.string("encyclopedia.searchPrompt") }
        static var missingData: String { LocalizationStore.string("encyclopedia.missingData") }
        static var judgmentTitle: String { LocalizationStore.string("encyclopedia.judgmentTitle") }
        static var tuanTitle: String { LocalizationStore.string("encyclopedia.tuanTitle") }
        static var linesTitle: String { LocalizationStore.string("encyclopedia.linesTitle") }
        static var disclaimer: String { LocalizationStore.string("encyclopedia.disclaimer") }
    }

    enum Interpret {
        static var placeholder: String { LocalizationStore.string("interpret.placeholder") }
        static var masterLabel: String { LocalizationStore.string("interpret.masterLabel") }
        static var thinking: String { LocalizationStore.string("interpret.thinking") }
        static var scriptureTitle: String { LocalizationStore.string("interpret.scriptureTitle") }
        static var scriptureDisclaimer: String { LocalizationStore.string("interpret.scriptureDisclaimer") }
    }

    enum History {
        static var emptyTitle: String { LocalizationStore.string("history.emptyTitle") }
        static var emptyDesc: String { LocalizationStore.string("history.emptyDesc") }
        static var noQuestion: String { LocalizationStore.string("history.noQuestion") }
        static var noTranscript: String { LocalizationStore.string("history.noTranscript") }
        static var corruptBoard: String { LocalizationStore.string("history.corruptBoard") }
        static var transcriptTitle: String { LocalizationStore.string("history.transcriptTitle") }
        static var viewBoard: String { LocalizationStore.string("history.viewBoard") }
        static var requestReadingFallback: String { LocalizationStore.string("history.requestReadingFallback") }
        static var continueAsk: String { LocalizationStore.string("history.continueAsk") }
        static var favoritesFilter: String { LocalizationStore.string("history.favoritesFilter") }
        static var allFilter: String { LocalizationStore.string("history.allFilter") }
        static var favorite: String { LocalizationStore.string("history.favorite") }
        static var unfavorite: String { LocalizationStore.string("history.unfavorite") }
        static var delete: String { LocalizationStore.string("history.delete") }
    }

    enum Error {
        static var invalidNumbers: String { LocalizationStore.string("error.invalidNumbers") }
        static var calendarOutOfRange: String { LocalizationStore.string("error.calendarOutOfRange") }
        static var badURL: String { LocalizationStore.string("error.badURL") }
        static var httpError: String { LocalizationStore.string("error.httpError") }
        static var insufficientCredits: String { LocalizationStore.string("error.insufficientCredits") }
        static var questionLimit: String { LocalizationStore.string("error.questionLimit") }
    }

    enum Account {
        static var title: String { LocalizationStore.string("account.title") }
        static var loginTitle: String { LocalizationStore.string("account.loginTitle") }
        static var loginDesc: String { LocalizationStore.string("account.loginDesc") }
        static var loginNavTitle: String { LocalizationStore.string("account.loginNavTitle") }
        static var signIn: String { LocalizationStore.string("account.signIn") }
        static var signOut: String { LocalizationStore.string("account.signOut") }
        static var notSignedInDesc: String { LocalizationStore.string("account.notSignedInDesc") }
        static var creditsTitle: String { LocalizationStore.string("account.creditsTitle") }
        static var freeCredits: String { LocalizationStore.string("account.freeCredits") }
        static var paidCredits: String { LocalizationStore.string("account.paidCredits") }
        static var subscriptionTitle: String { LocalizationStore.string("account.subscriptionTitle") }
        static var subscriptionDesc: String { LocalizationStore.string("account.subscriptionDesc") }
        static var subscribed: String { LocalizationStore.string("account.subscribed") }
        static var expiresAt: String { LocalizationStore.string("account.expiresAt") }
        static var subscribe: String { LocalizationStore.string("account.subscribe") }
        static var topUpTitle: String { LocalizationStore.string("account.topUpTitle") }
        static var topUpDesc: String { LocalizationStore.string("account.topUpDesc") }
        static var buy: String { LocalizationStore.string("account.buy") }
        static var readings: String { LocalizationStore.string("account.readings") }
        static var paymentTitle: String { LocalizationStore.string("account.paymentTitle") }
        static var paymentSubtitle: String { LocalizationStore.string("account.paymentSubtitle") }
        static var restorePurchases: String { LocalizationStore.string("account.restorePurchases") }
        static var termsOfService: String { LocalizationStore.string("account.termsOfService") }
        static var privacyPolicy: String { LocalizationStore.string("account.privacyPolicy") }
        static var subscriptionPerMonth: String { LocalizationStore.string("account.subscriptionPerMonth") }
        static var subscriptionFeature1: String { LocalizationStore.string("account.subscriptionFeature1") }
        static var subscriptionFeature2: String { LocalizationStore.string("account.subscriptionFeature2") }
        static var subscriptionFeature3: String { LocalizationStore.string("account.subscriptionFeature3") }
        static var topUpOneTime: String { LocalizationStore.string("account.topUpOneTime") }
        static var topUpPerReading: String { LocalizationStore.string("account.topUpPerReading") }
        static var manageSubscription: String { LocalizationStore.string("account.manageSubscription") }
        static var viewPlans: String { LocalizationStore.string("account.viewPlans") }
        static var emailLoginTitle: String { LocalizationStore.string("account.emailLoginTitle") }
        static var emailPlaceholder: String { LocalizationStore.string("account.emailPlaceholder") }
        static var codePlaceholder: String { LocalizationStore.string("account.codePlaceholder") }
        static var sendCode: String { LocalizationStore.string("account.sendCode") }
        static var resend: String { LocalizationStore.string("account.resend") }
        static var codeSent: String { LocalizationStore.string("account.codeSent") }
        static var invalidEmail: String { LocalizationStore.string("account.invalidEmail") }
        static var invalidCode: String { LocalizationStore.string("account.invalidCode") }
        static var codeCooldown: String { LocalizationStore.string("account.codeCooldown") }
        static var sendCodeFailed: String { LocalizationStore.string("account.sendCodeFailed") }
        static var codeLogin: String { LocalizationStore.string("account.codeLogin") }
        static var passwordLogin: String { LocalizationStore.string("account.passwordLogin") }
        static var passwordPlaceholder: String { LocalizationStore.string("account.passwordPlaceholder") }
        static var passwordLoginHint: String { LocalizationStore.string("account.passwordLoginHint") }
        static var wrongPassword: String { LocalizationStore.string("account.wrongPassword") }
        static var setPassword: String { LocalizationStore.string("account.setPassword") }
        static var changePassword: String { LocalizationStore.string("account.changePassword") }
        static var passwordDesc: String { LocalizationStore.string("account.passwordDesc") }
        static var newPasswordPlaceholder: String { LocalizationStore.string("account.newPasswordPlaceholder") }
        static var confirmPasswordPlaceholder: String { LocalizationStore.string("account.confirmPasswordPlaceholder") }
        static var passwordMismatch: String { LocalizationStore.string("account.passwordMismatch") }
        static var passwordTooShort: String { LocalizationStore.string("account.passwordTooShort") }
        static var passwordSetSuccess: String { LocalizationStore.string("account.passwordSetSuccess") }
        static var passwordSetFailed: String { LocalizationStore.string("account.passwordSetFailed") }
    }
}
